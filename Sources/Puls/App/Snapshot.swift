#if !APPSTORE || SNAPSHOTS
import AppKit
import SwiftUI

/// `Puls --snapshot <ordner>` zeigt das Panel nacheinander mit allen Ansichten
/// und speichert Bildschirmfotos des eigenen Fensters (für Doku und Sichtprüfung).
@MainActor
final class Snapshot {
    private let directory: URL
    private let monitor = SystemMonitor(prefs: .shared)
    private let state = PanelState()
    private var panel: GlassPanel!

    private func argument(_ name: String) -> String? {
        guard let i = CommandLine.arguments.firstIndex(of: name), i + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[i + 1]
    }

    init(directory: String) {
        self.directory = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func start() {
        let root = PanelRootView().environment(monitor).environment(Preferences.shared).environment(state)
        panel = GlassPanel(rootView: root)
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let appearanceArg = CommandLine.arguments.contains("--light") ? NSAppearance(named: .aqua) : nil
        if let appearanceArg { NSApp.appearance = appearanceArg }
        panel.setFrameTopLeftPoint(NSPoint(x: screen.maxX - PanelMetrics.width - 60, y: screen.maxY - 50))
        monitor.redactsAddresses = true
        monitor.start()
        monitor.isPanelVisible = true
        panel.orderFrontRegardless()
        let warmup = Double(argument("--warmup") ?? "") ?? 6
        if warmup > 30 { Preferences.shared.refreshInterval = 1 } // Verläufe schneller füllen

        let routes: [(String, Route)] = [("overview", .overview)]
            + Module.allCases.map { ($0.rawValue, Route.detail($0)) }
            + [("settings", .settings)]
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(warmup))
            for (name, route) in routes {
                state.route = route
                try? await Task.sleep(for: .seconds(1.6))
                capture(name: name)
            }
            saveMenuBarLabel()
            NSApp.terminate(nil)
        }
    }

    private func capture(name: String) {
        guard let image = Self.captureImage(of: panel, windowOnly: true) else {
            print("Aufnahme fehlgeschlagen:", name)
            return
        }
        Self.write(image, to: directory.appendingPathComponent("\(name).png"))
    }

    /// Nimmt das eigene Fenster samt Schreibtisch dahinter auf (ohne Bildschirmaufnahme-Freigabe möglich).
    static func captureImage(of panel: NSWindow, margin: CGFloat = 24, windowOnly: Bool = false) -> CGImage? {
        typealias Fn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let fn = unsafeBitCast(symbol, to: Fn.self)
        // Bereich des Panels in globalen CG-Koordinaten (Ursprung oben links).
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let f = panel.frame.insetBy(dx: -margin, dy: -margin)
        let rect = CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
        // onScreenBelowWindow (4) | includingWindow (8): Panel samt Schreibtisch dahinter; bestResolution = 8
        let options: UInt32 = windowOnly || CommandLine.arguments.contains("--window-only") ? 8 : 4 | 8
        return fn(options == 8 ? .null : rect, options, UInt32(panel.windowNumber), options == 8 ? 1 | 8 : 8)?.takeRetainedValue()
    }

    private func saveMenuBarLabel() {
        for dark in [false, true] {
            let renderer = ImageRenderer(content: MenuBarLabel(monitor: monitor, prefs: .shared, darkMenuBar: dark)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(dark ? Color(white: 0.12) : Color(white: 0.94)))
            renderer.scale = 3
            if let image = renderer.cgImage {
                Self.write(image, to: directory.appendingPathComponent(dark ? "menubar-dark.png" : "menubar-light.png"))
            }
        }
    }

    static func write(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("gespeichert:", url.path, image.width, "x", image.height)
    }
}
#endif
