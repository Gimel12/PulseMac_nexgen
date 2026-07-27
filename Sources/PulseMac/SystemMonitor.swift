import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty
    @Published private(set) var history: [Double] = []
    @Published private(set) var storageLocations: [StorageLocation] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isScanningStorage = false
    @Published var lastError: String?

    private var refreshTask: Task<Void, Never>?
    private var storageTask: Task<Void, Never>?

    init() {
        refresh()
        scanStorage()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.refresh()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        storageTask?.cancel()
    }

    var healthSymbol: String {
        if snapshot.cpuPercent > 80 || memoryFraction > 0.92 { return "exclamationmark.circle.fill" }
        if snapshot.cpuPercent > 55 || memoryFraction > 0.82 { return "gauge.with.dots.needle.67percent" }
        return "checkmark.circle.fill"
    }

    var memoryFraction: Double {
        guard snapshot.memoryTotal > 0 else { return 0 }
        return Double(snapshot.memoryUsed) / Double(snapshot.memoryTotal)
    }

    var diskFraction: Double {
        guard snapshot.diskTotal > 0 else { return 0 }
        return Double(snapshot.diskUsed) / Double(snapshot.diskTotal)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let result = await Task.detached(priority: .utility) {
                SystemSampler.sample()
            }.value
            snapshot = result
            history.append(result.cpuPercent)
            if history.count > 40 { history.removeFirst(history.count - 40) }
            isRefreshing = false
        }
    }

    func stop(process: RunningProcess, force: Bool) -> String? {
        guard process.pid > 1, process.pid != getpid() else {
            return "PulseMac will not stop this protected process."
        }
        let signalValue = force ? SIGKILL : SIGTERM
        if Darwin.kill(process.pid, signalValue) == 0 {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                refresh()
            }
            return nil
        }
        if errno == EPERM {
            return "macOS denied permission. This process belongs to the system or another user."
        }
        return String(cString: strerror(errno))
    }

    func scanStorage() {
        guard !isScanningStorage else { return }
        isScanningStorage = true
        storageTask = Task {
            let result = await Task.detached(priority: .utility) {
                StorageScanner.scan()
            }.value
            storageLocations = result
            isScanningStorage = false
        }
    }

    func moveOldCachesToTrash() async -> String? {
        isScanningStorage = true
        let result = await Task.detached(priority: .utility) {
            StorageScanner.trashOldCacheItems()
        }.value
        isScanningStorage = false
        scanStorage()
        return result
    }
}

enum SystemSampler {
    static func sample() -> SystemSnapshot {
        let processes = readProcesses()
        let memory = readMemory()
        let disk = readDisk()
        let cpuTotal = processes.reduce(0) { $0 + $1.cpu }
        let cores = max(1, Foundation.ProcessInfo.processInfo.activeProcessorCount)

        return SystemSnapshot(
            date: .now,
            cpuPercent: min(100, cpuTotal / Double(cores)),
            memoryUsed: memory.used,
            memoryTotal: Foundation.ProcessInfo.processInfo.physicalMemory,
            compressedBytes: memory.compressed,
            swapUsed: memory.swap,
            diskUsed: disk.used,
            diskTotal: disk.total,
            uptime: Foundation.ProcessInfo.processInfo.systemUptime,
            processes: processes,
            servers: readServers()
        )
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func readProcesses() -> [RunningProcess] {
        let output = run("/bin/ps", ["-axo", "pid=,ppid=,uid=,%cpu=,%mem=,rss=,etime=,comm="])
        return output.split(separator: "\n").compactMap { line in
            let fields = line.split(maxSplits: 7, whereSeparator: \.isWhitespace)
            guard fields.count == 8,
                  let pid = Int32(fields[0]),
                  let parent = Int32(fields[1]),
                  let uid = UInt32(fields[2]),
                  let cpu = Double(fields[3]),
                  let memoryPercent = Double(fields[4]),
                  let rssKB = UInt64(fields[5]) else { return nil }
            return RunningProcess(
                pid: pid,
                parentPID: parent,
                uid: uid,
                cpu: cpu,
                memoryPercent: memoryPercent,
                residentBytes: rssKB * 1024,
                elapsed: String(fields[6]),
                executable: String(fields[7]).trimmingCharacters(in: .whitespaces)
            )
        }
    }

    private static func readServers() -> [ListeningServer] {
        let output = run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcPn"])
        var result: [ListeningServer] = []
        var pid: Int32?
        var command = ""
        var protocolName = "TCP"

        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine)
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            switch prefix {
            case "p": pid = Int32(value)
            case "c": command = value
            case "P": protocolName = value
            case "n":
                guard let currentPID = pid,
                      let portString = value.split(separator: ":").last,
                      let port = Int(portString) else { continue }
                result.append(ListeningServer(
                    pid: currentPID,
                    processName: command,
                    address: value,
                    port: port,
                    protocolName: protocolName
                ))
            default: break
            }
        }
        return Array(Set(result)).sorted { lhs, rhs in
            lhs.port == rhs.port ? lhs.processName < rhs.processName : lhs.port < rhs.port
        }
    }

    private static func readMemory() -> (used: UInt64, compressed: UInt64, swap: UInt64) {
        let pageSize = UInt64(getpagesize())
        let vmOutput = run("/usr/bin/vm_stat", [])
        var freePages: UInt64 = 0
        var compressedPages: UInt64 = 0
        for line in vmOutput.split(separator: "\n") {
            let text = String(line)
            let number = UInt64(text.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .filter { !$0.isEmpty }.last ?? "") ?? 0
            if text.hasPrefix("Pages free:") { freePages = number }
            if text.hasPrefix("Pages speculative:") { freePages += number }
            if text.hasPrefix("Pages occupied by compressor:") { compressedPages = number }
        }

        let total = Foundation.ProcessInfo.processInfo.physicalMemory
        let used = total > freePages * pageSize ? total - freePages * pageSize : 0
        let swapOutput = run("/usr/sbin/sysctl", ["-n", "vm.swapusage"])
        let pattern = #"used = ([0-9.]+)([MG])"#
        var swap: UInt64 = 0
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: swapOutput, range: NSRange(swapOutput.startIndex..., in: swapOutput)),
           let valueRange = Range(match.range(at: 1), in: swapOutput),
           let unitRange = Range(match.range(at: 2), in: swapOutput),
           let value = Double(swapOutput[valueRange]) {
            swap = UInt64(value * (swapOutput[unitRange] == "G" ? 1_073_741_824 : 1_048_576))
        }
        return (used, compressedPages * pageSize, swap)
    }

    private static func readDisk() -> (used: UInt64, total: UInt64) {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = UInt64(max(0, values.volumeTotalCapacity ?? 0))
            let available = UInt64(max(0, values.volumeAvailableCapacityForImportantUsage ?? 0))
            return (total > available ? total - available : 0, total)
        } catch {
            return (0, 1)
        }
    }
}

enum StorageScanner {
    static func scan() -> [StorageLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let locations: [(String, String, URL, String, Bool)] = [
            ("Downloads", "arrow.down.circle.fill", home.appending(path: "Downloads"), "Review downloaded files", false),
            ("Trash", "trash.fill", home.appending(path: ".Trash"), "Files already in Trash", false),
            ("Old app caches", "sparkles", home.appending(path: "Library/Caches"), "Cache items unused for 30+ days", true)
        ]
        return locations.map { name, symbol, url, detail, cleanable in
            StorageLocation(
                name: name,
                symbol: symbol,
                url: url,
                bytes: cleanable ? oldCacheSize(url) : folderSize(url),
                detail: detail,
                isCleanable: cleanable
            )
        }
    }

    static func trashOldCacheItems() -> String? {
        let cacheURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Caches")
        let candidates = eligibleOldCacheChildren(in: cacheURL)
        guard !candidates.isEmpty else {
            return "No fully inactive cache folders are currently eligible."
        }

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return "Could not inspect your cache folder."
        }

        var failed = 0
        for child in candidates {
            do {
                _ = try FileManager.default.trashItem(at: child, resultingItemURL: nil)
            } catch {
                failed += 1
            }
        }
        return failed == 0 ? nil : "\(failed) cache items could not be moved because they are in use or protected."
    }

    private static func oldCacheSize(_ cacheURL: URL) -> UInt64 {
        eligibleOldCacheChildren(in: cacheURL).reduce(0) { $0 + folderSize($1) }
    }

    private static func eligibleOldCacheChildren(in cacheURL: URL) -> [URL] {
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return children.filter { child in
            guard let childDate = try? child.resourceValues(
                forKeys: [.contentModificationDateKey]
            ).contentModificationDate, childDate < cutoff else { return false }

            guard let enumerator = FileManager.default.enumerator(
                at: child,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return true }

            for case let item as URL in enumerator {
                if let modified = try? item.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate, modified >= cutoff {
                    return false
                }
            }
            return true
        }
    }

    private static func folderSize(_ url: URL) -> UInt64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else { continue }
            total += UInt64(max(0, values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0))
        }
        return total
    }
}
