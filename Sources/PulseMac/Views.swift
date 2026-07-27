import AppKit
import Charts
import SwiftUI

private let accent = Color(red: 0.36, green: 0.92, blue: 0.76)
private let purple = Color(red: 0.56, green: 0.45, blue: 1.0)

struct ContentView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [accent, purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PulseMac").font(.headline)
                        Text("System control center").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)

                List(SidebarItem.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.symbol)
                        .tag(item)
                        .padding(.vertical, 5)
                }
                .listStyle(.sidebar)

                StatusPill()
                    .padding(14)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 260)
        } detail: {
            ZStack {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor), Color.black.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                switch selection ?? .overview {
                case .overview: OverviewView()
                case .processes: ProcessesView()
                case .servers: ServersView()
                case .storage: StorageView()
                }
            }
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Button {
                    monitor.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(monitor.isRefreshing)
                Text("Updated \(monitor.snapshot.date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct OverviewView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    private var topProcesses: [RunningProcess] {
        Array(monitor.snapshot.processes.sorted { $0.cpu > $1.cpu }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Your Mac at a glance", subtitle: "Live health, pressure, and the processes that need attention.")

                HStack(spacing: 14) {
                    MetricCard(
                        title: "CPU",
                        value: "\(Int(monitor.snapshot.cpuPercent))%",
                        detail: monitor.snapshot.cpuPercent > 70 ? "Working hard" : "Running smoothly",
                        symbol: "cpu",
                        fraction: monitor.snapshot.cpuPercent / 100,
                        tint: monitor.snapshot.cpuPercent > 70 ? .orange : accent
                    )
                    MetricCard(
                        title: "Memory",
                        value: ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.memoryUsed), countStyle: .memory),
                        detail: "of \(ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.memoryTotal), countStyle: .memory))",
                        symbol: "memorychip",
                        fraction: monitor.memoryFraction,
                        tint: monitor.memoryFraction > 0.9 ? .orange : purple
                    )
                    MetricCard(
                        title: "Disk",
                        value: ByteCountFormatter.string(fromByteCount: Int64(monitor.snapshot.diskTotal - monitor.snapshot.diskUsed), countStyle: .file),
                        detail: "available",
                        symbol: "internaldrive",
                        fraction: monitor.diskFraction,
                        tint: monitor.diskFraction > 0.9 ? .red : .cyan
                    )
                    MetricCard(
                        title: "Servers",
                        value: "\(monitor.snapshot.servers.count)",
                        detail: "listening locally",
                        symbol: "network",
                        fraction: min(1, Double(monitor.snapshot.servers.count) / 8),
                        tint: .pink
                    )
                }

                HStack(alignment: .top, spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("CPU activity", systemImage: "waveform.path.ecg")
                                .font(.headline)
                            Chart(Array(monitor.history.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Sample", index),
                                    y: .value("CPU", value)
                                )
                                .foregroundStyle(
                                    LinearGradient(colors: [accent.opacity(0.45), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                )
                                LineMark(
                                    x: .value("Sample", index),
                                    y: .value("CPU", value)
                                )
                                .foregroundStyle(accent)
                                .lineStyle(.init(lineWidth: 2.5, lineCap: .round))
                            }
                            .chartYScale(domain: 0...100)
                            .chartYAxis {
                                AxisMarks(values: [0, 50, 100]) { value in
                                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                                    AxisValueLabel {
                                        if let number = value.as(Int.self) { Text("\(number)%") }
                                    }
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 185)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Label("Memory details", systemImage: "memorychip")
                                .font(.headline)
                            DetailRow(label: "In use", value: monitor.snapshot.memoryUsed.formattedBytes)
                            DetailRow(label: "Compressed", value: monitor.snapshot.compressedBytes.formattedBytes)
                            DetailRow(label: "Swap", value: monitor.snapshot.swapUsed.formattedBytes)
                            Divider()
                            Text("Compressed memory and swap can make app switching feel slower, even when your Mac still has room to work.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(width: 280)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Top consumers", systemImage: "bolt.fill").font(.headline)
                            Spacer()
                            Text("CPU right now").font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(topProcesses) { process in
                            ProcessCompactRow(process: process)
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

struct ProcessesView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var query = ""
    @State private var sort: ProcessSort = .cpu
    @State private var showSystem = true
    @State private var pendingAction: PendingProcessAction?
    @State private var actionError: String?

    private var matchingProcesses: [RunningProcess] {
        var values = monitor.snapshot.processes.filter {
            (showSystem || !$0.isSystem) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || "\($0.pid)".contains(query))
        }
        switch sort {
        case .cpu: values.sort { $0.cpu > $1.cpu }
        case .memory: values.sort { $0.residentBytes > $1.residentBytes }
        case .name: values.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return values
    }

    private var displayedProcesses: [RunningProcess] {
        Array(matchingProcesses.prefix(query.isEmpty ? 120 : 250))
    }

    var body: some View {
        VStack(spacing: 18) {
            PageHeader(title: "Processes", subtitle: "Find what is using your Mac and stop it safely.")

            HStack(spacing: 12) {
                TextField("Search by app, command, or PID", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("Sort", selection: $sort) {
                    ForEach(ProcessSort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                Toggle("System processes", isOn: $showSystem)
                    .toggleStyle(.switch)
            }

            HStack {
                Text("Showing \(displayedProcesses.count) of \(matchingProcesses.count) matching processes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Search to reveal processes outside the live top list")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Table(displayedProcesses) {
                TableColumn("Process") { process in
                    HStack(spacing: 9) {
                        Image(systemName: process.isSystem ? "gearshape.2.fill" : "app.fill")
                            .foregroundStyle(process.isHeavy ? .orange : (process.isSystem ? .secondary : accent))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(process.name).fontWeight(process.isHeavy ? .semibold : .regular)
                            Text("PID \(process.pid) · \(process.elapsed)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 260, ideal: 360)

                TableColumn("CPU") { process in
                    UsageBadge(value: process.cpu, suffix: "%", warning: process.cpu >= 50)
                }
                .width(90)

                TableColumn("Memory") { process in
                    Text(process.residentBytes.formattedBytes)
                        .monospacedDigit()
                }
                .width(105)

                TableColumn("Type") { process in
                    Text(process.isSystem ? "System" : "User")
                        .font(.caption)
                        .foregroundStyle(process.isSystem ? .secondary : accent)
                }
                .width(70)

                TableColumn("") { process in
                    Menu {
                        Button("Stop normally") {
                            pendingAction = PendingProcessAction(process: process, force: false)
                        }
                        Button("Force quit", role: .destructive) {
                            pendingAction = PendingProcessAction(process: process, force: true)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(process.pid <= 1 || process.pid == getpid())
                }
                .width(42)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(28)
        .alert(
            pendingAction?.force == true ? "Force quit this process?" : "Stop this process?",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            presenting: pendingAction
        ) { action in
            Button("Cancel", role: .cancel) {}
            Button(action.force ? "Force Quit" : "Stop", role: action.force ? .destructive : nil) {
                actionError = monitor.stop(process: action.process, force: action.force)
                pendingAction = nil
            }
        } message: { action in
            Text(action.force
                 ? "\(action.process.name) (PID \(action.process.pid)) will be stopped immediately and may lose unsaved work."
                 : "\(action.process.name) (PID \(action.process.pid)) will be asked to close gracefully.")
        }
        .alert("Couldn’t stop process", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }
}

private struct PendingProcessAction: Identifiable {
    let process: RunningProcess
    let force: Bool
    var id: String { "\(process.pid)-\(force)" }
}

struct ServersView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var pendingProcess: RunningProcess?
    @State private var actionError: String?

    private func process(for server: ListeningServer) -> RunningProcess? {
        monitor.snapshot.processes.first { $0.pid == server.pid }
    }

    var body: some View {
        VStack(spacing: 20) {
            PageHeader(title: "Web Servers", subtitle: "Everything currently listening for TCP connections on your Mac.")

            if monitor.snapshot.servers.isEmpty {
                ContentUnavailableView(
                    "No listening servers",
                    systemImage: "network.slash",
                    description: Text("PulseMac checks local TCP ports every few seconds.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(monitor.snapshot.servers) { server in
                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9).fill(accent.opacity(0.13))
                                            Image(systemName: "network").foregroundStyle(accent)
                                        }
                                        .frame(width: 38, height: 38)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(server.processName).font(.headline)
                                            Text("PID \(server.pid)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(":\(server.port)")
                                            .font(.system(.title3, design: .monospaced, weight: .bold))
                                            .foregroundStyle(accent)
                                    }
                                    Text(server.address)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    HStack {
                                        if let url = server.localURL {
                                            Button("Open") { NSWorkspace.shared.open(url) }
                                                .buttonStyle(.borderedProminent)
                                                .tint(accent)
                                                .foregroundStyle(.black)
                                        }
                                        Spacer()
                                        Button("Stop", role: .destructive) {
                                            pendingProcess = process(for: server)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(process(for: server) == nil)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(28)
        .alert("Stop this server?", isPresented: Binding(
            get: { pendingProcess != nil },
            set: { if !$0 { pendingProcess = nil } }
        ), presenting: pendingProcess) { process in
            Button("Cancel", role: .cancel) {}
            Button("Stop", role: .destructive) {
                actionError = monitor.stop(process: process, force: false)
                pendingProcess = nil
            }
        } message: { process in
            Text("\(process.name) (PID \(process.pid)) will be asked to stop. Any services it hosts will go offline.")
        }
        .alert("Couldn’t stop server", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }
}

struct StorageView: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var confirmCacheCleanup = false
    @State private var cleanupMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Storage", subtitle: "Understand what is taking space and recover it without risky deletion.")

                GlassCard {
                    HStack(spacing: 22) {
                        RingProgress(fraction: monitor.diskFraction, tint: monitor.diskFraction > 0.9 ? .red : accent)
                            .frame(width: 112, height: 112)
                            .overlay {
                                VStack(spacing: 0) {
                                    Text("\(Int(monitor.diskFraction * 100))%").font(.title2.bold())
                                    Text("used").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("\((monitor.snapshot.diskTotal - monitor.snapshot.diskUsed).formattedBytes) available")
                                .font(.title2.bold())
                            Text("\(monitor.snapshot.diskUsed.formattedBytes) used of \(monitor.snapshot.diskTotal.formattedBytes)")
                                .foregroundStyle(.secondary)
                            ProgressView(value: monitor.diskFraction)
                                .tint(accent)
                                .frame(maxWidth: 420)
                        }
                        Spacer()
                    }
                }

                HStack {
                    Text("Places worth reviewing").font(.title3.bold())
                    Spacer()
                    Button {
                        monitor.scanStorage()
                    } label: {
                        Label(monitor.isScanningStorage ? "Scanning…" : "Scan again", systemImage: "arrow.clockwise")
                    }
                    .disabled(monitor.isScanningStorage)
                }

                ForEach(monitor.storageLocations) { location in
                    GlassCard {
                        HStack(spacing: 15) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(purple.opacity(0.14))
                                Image(systemName: location.symbol).font(.title2).foregroundStyle(purple)
                            }
                            .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name).font(.headline)
                                Text(location.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(location.bytes.formattedBytes)
                                .font(.title3.monospacedDigit().bold())
                            Button("Reveal") {
                                NSWorkspace.shared.activateFileViewerSelecting([location.url])
                            }
                            .buttonStyle(.bordered)
                            if location.isCleanable {
                                Button("Move to Trash") {
                                    confirmCacheCleanup = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(purple)
                            }
                        }
                    }
                }

                Label("Cleanup only targets top-level app cache folders unused for at least 30 days. Items are moved to Trash so they remain recoverable.", systemImage: "shield.checkered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .confirmationDialog("Move old app caches to Trash?", isPresented: $confirmCacheCleanup) {
            Button("Move old caches to Trash", role: .destructive) {
                Task {
                    cleanupMessage = await monitor.moveOldCachesToTrash() ?? "Old cache items were moved to Trash."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only cache folders unused for 30 days or more are included. Apps may recreate caches later.")
        }
        .alert("Cleanup finished", isPresented: Binding(
            get: { cleanupMessage != nil },
            set: { if !$0 { cleanupMessage = nil } }
        )) {
            Button("OK") { cleanupMessage = nil }
        } message: {
            Text(cleanupMessage ?? "")
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PulseMac", systemImage: "waveform.path.ecg").font(.headline)
            HStack {
                Label("\(Int(monitor.snapshot.cpuPercent))% CPU", systemImage: "cpu")
                Spacer()
                Label("\(Int(monitor.memoryFraction * 100))% RAM", systemImage: "memorychip")
            }
            .font(.caption)
            Divider()
            Text("\(monitor.snapshot.servers.count) listening server\(monitor.snapshot.servers.count == 1 ? "" : "s")")
                .font(.caption)
            Button("Refresh now") { monitor.refresh() }
            Divider()
            Button("Quit PulseMac") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 250)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let fraction: Double
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(title, systemImage: symbol).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    RingProgress(fraction: fraction, tint: tint).frame(width: 30, height: 30)
                }
                Text(value).font(.system(size: 25, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct RingProgress: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.09), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct StatusPill: View {
    @EnvironmentObject private var monitor: SystemMonitor

    private var status: (String, Color) {
        if monitor.snapshot.cpuPercent > 80 || monitor.memoryFraction > 0.94 { return ("Needs attention", .orange) }
        if monitor.snapshot.cpuPercent > 55 || monitor.memoryFraction > 0.86 { return ("Under pressure", .yellow) }
        return ("Looking healthy", accent)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(status.1).frame(width: 8, height: 8).shadow(color: status.1, radius: 4)
            Text(status.0).font(.caption.weight(.medium))
            Spacer()
        }
        .padding(10)
        .background(status.1.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProcessCompactRow: View {
    let process: RunningProcess

    var body: some View {
        HStack {
            Image(systemName: process.isSystem ? "gearshape.fill" : "app.fill")
                .foregroundStyle(process.isHeavy ? .orange : .secondary)
                .frame(width: 24)
            Text(process.name).lineLimit(1)
            Text("PID \(process.pid)").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Text(process.residentBytes.formattedBytes).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 78, alignment: .trailing)
            UsageBadge(value: process.cpu, suffix: "%", warning: process.cpu >= 50)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }
}

struct UsageBadge: View {
    let value: Double
    let suffix: String
    let warning: Bool

    var body: some View {
        Text("\(value, specifier: "%.1f")\(suffix)")
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(warning ? .orange : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((warning ? Color.orange : Color.white).opacity(0.08), in: Capsule())
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

extension UInt64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}
