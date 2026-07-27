import SwiftUI

@main
struct PulseMacApp: App {
    @StateObject private var monitor = SystemMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                .frame(minWidth: 1040, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Now") {
                    monitor.refresh()
                }
                .keyboardShortcut("r")
            }
        }

        MenuBarExtra("PulseMac", systemImage: monitor.healthSymbol) {
            MenuBarView()
                .environmentObject(monitor)
        }
    }
}
