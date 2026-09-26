import AppKit
import SwiftUI

/// Rahmenloses, schwebendes Panel mit echtem Liquid-Glass-Hintergrund (NSGlassEffectView).
final class GlassPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        let glassFrame = PanelMetrics.glassFrameInWindow
        let windowRect = NSRect(origin: .zero, size: PanelMetrics.windowSize)
        super.init(contentRect: windowRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        // Den Schatten zeichnet das Glas selbst, rund und im durchsichtigen Rand. Ein Fensterschatten
        // würde aus dem Rand ein Rechteck berechnen.
        hasShadow = false
        level = .statusBar
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let glass = NSGlassEffectView()
        glass.cornerRadius = PanelMetrics.cornerRadius
        glass.style = .regular
        // Leichte Tönung, damit Text auch über unruhigem Hintergrund gut lesbar bleibt.
        glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.28)
        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []
        glass.contentView = host
        glass.frame = glassFrame
        glass.autoresizingMask = [.width, .height]
        let container = NSView(frame: windowRect)
        container.addSubview(glass)
        contentView = container
        self.glass = glass
    }

    private weak var glass: NSView?

    /// Liegt der Punkt (Fensterkoordinaten) im durchsichtigen Rand statt auf dem Glas?
    func isInShadowMargin(_ point: NSPoint) -> Bool {
        guard let glass else { return false }
        return !glass.frame.contains(point)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
