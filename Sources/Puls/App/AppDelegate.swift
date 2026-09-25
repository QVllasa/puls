import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SystemMonitor!
    private var controller: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SystemMonitor(prefs: .shared)
        controller = StatusItemController(monitor: monitor, prefs: .shared)
        monitor.start()

        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.controller.openPanel() }
        }
    }
}
