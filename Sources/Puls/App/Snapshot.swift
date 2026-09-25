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
    private var backdrop: NSWindow?

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
        monitor.start()
        monitor.isPanelVisible = true
        if CommandLine.arguments.contains("--backdrop") { showBackdrop() }
        panel.orderFrontRegardless()
        let warmup = Double(argument("--warmup") ?? "") ?? 6

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

    /// Farbiger Hintergrund hinter dem Panel, damit der Glaseffekt auf Screenshots sichtbar wird.
    private func showBackdrop() {
        let frame = panel.frame.insetBy(dx: -48, dy: -48)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = panel.level
        window.isOpaque = true
        window.contentView = NSHostingView(rootView: SnapshotBackdrop())
        window.orderFrontRegardless()
        backdrop = window
    }

    private func capture(name: String) {
        guard let image = Self.captureImage(of: panel) else {
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

struct SnapshotBackdrop: View {
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.45, 0.55], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: [
            Color(red: 0.10, green: 0.20, blue: 0.55), Color(red: 0.35, green: 0.20, blue: 0.75), Color(red: 0.85, green: 0.35, blue: 0.55),
            Color(red: 0.05, green: 0.55, blue: 0.75), Color(red: 0.30, green: 0.35, blue: 0.90), Color(red: 0.95, green: 0.55, blue: 0.35),
            Color(red: 0.10, green: 0.65, blue: 0.55), Color(red: 0.20, green: 0.30, blue: 0.70), Color(red: 0.60, green: 0.25, blue: 0.70),
        ])
        .overlay {
            // Ein paar Formen, damit die Glas-Verzerrung erkennbar ist
            ZStack {
                Circle().fill(.white.opacity(0.35)).frame(width: 140).offset(x: -150, y: -220)
                RoundedRectangle(cornerRadius: 30).fill(.yellow.opacity(0.55)).frame(width: 160, height: 90).rotationEffect(.degrees(-18)).offset(x: 140, y: 40)
                Circle().fill(.cyan.opacity(0.5)).frame(width: 200).offset(x: -120, y: 260)
            }
            .blur(radius: 2)
        }
    }
}
