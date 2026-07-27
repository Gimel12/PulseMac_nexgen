import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case processes = "Processes"
    case servers = "Web Servers"
    case storage = "Storage"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .processes: "cpu"
        case .servers: "network"
        case .storage: "internaldrive"
        }
    }
}

struct RunningProcess: Identifiable, Hashable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let uid: UInt32
    let cpu: Double
    let memoryPercent: Double
    let residentBytes: UInt64
    let elapsed: String
    let executable: String

    var id: Int32 { pid }
    var name: String {
        let url = URL(fileURLWithPath: executable)
        let value = url.lastPathComponent
        return value.isEmpty ? executable : value
    }
    var isSystem: Bool { uid == 0 || executable.hasPrefix("/System/") || executable.hasPrefix("/usr/") }
    var isHeavy: Bool { cpu >= 50 || residentBytes >= 1_000_000_000 }
}

struct ListeningServer: Identifiable, Hashable, Sendable {
    let pid: Int32
    let processName: String
    let address: String
    let port: Int
    let protocolName: String

    var id: String { "\(pid)-\(address)-\(port)-\(protocolName)" }
    var localURL: URL? {
        URL(string: "http://localhost:\(port)")
    }
}

struct SystemSnapshot: Sendable {
    let date: Date
    let cpuPercent: Double
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let compressedBytes: UInt64
    let swapUsed: UInt64
    let diskUsed: UInt64
    let diskTotal: UInt64
    let uptime: TimeInterval
    let processes: [RunningProcess]
    let servers: [ListeningServer]

    static let empty = SystemSnapshot(
        date: .now,
        cpuPercent: 0,
        memoryUsed: 0,
        memoryTotal: 1,
        compressedBytes: 0,
        swapUsed: 0,
        diskUsed: 0,
        diskTotal: 1,
        uptime: 0,
        processes: [],
        servers: []
    )
}

struct StorageLocation: Identifiable, Hashable, Sendable {
    let name: String
    let symbol: String
    let url: URL
    let bytes: UInt64
    let detail: String
    let isCleanable: Bool

    var id: String { url.path }
}

enum ProcessSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case name = "Name"
    var id: String { rawValue }
}
