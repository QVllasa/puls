import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SystemMonitor!
    private var controller: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = SystemMonitor(prefs: .shared)
        controller = StatusItemController(monitor: monitor, prefs: .shared)
        monitor.start()
        UpdateChecker.shared.start()
        enableLaunchAtLoginOnFirstRun()

        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.controller.openPanel() }
        }
        #if !APPSTORE
        // Diagnose: `--capture <datei.png>` öffnet das Panel und fotografiert es an seiner echten Position.
        if let i = CommandLine.arguments.firstIndex(of: "--capture"), i + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.controller.openPanel() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if let image = Snapshot.captureImage(of: self.controller.panel, windowOnly: true) {
                    Snapshot.write(image, to: URL(fileURLWithPath: path))
                }
            }
        }
        #endif
    }

    /// Beim allerersten Start trägt sich Puls als Anmeldeobjekt ein, damit es mit dem Mac startet.
    /// Abschalten lässt sich das jederzeit in den Einstellungen.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "loginItemConfigured"
        guard Bundle.main.bundleURL.pathExtension == "app",
              !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        if Flavor.isAppStore {
            // Store: nicht ungefragt eintragen, sondern beim ersten Start das Panel mit der Frage zeigen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.controller.openPanel() }
        } else {
            Preferences.shared.launchAtLogin = true
        }
    }
}
