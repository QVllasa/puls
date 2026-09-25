import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor: SystemMonitor
    private let prefs: Preferences
    private let state = PanelState()
    private(set) lazy var panel: GlassPanel = makePanel()
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?
    private var lastLabelKey = ""
    private var lastRenderKey = ""
    private var appearanceObservation: NSKeyValueObservation?

    init(monitor: SystemMonitor, prefs: Preferences) {
        self.monitor = monitor
        self.prefs = prefs
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Puls Systemmonitor")
        }
        state.close = { [weak self] in self?.closePanel() }
        monitor.onUpdate = { [weak self] in self?.updateLabel() }
        updateLabel()

        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.updateLabel() }
        }
        observePrefs()
    }

    private func observePrefs() {
        updateLabel()
        withObservationTracking {
            _ = prefs.menuBarMetrics; _ = prefs.useFahrenheit; _ = prefs.coloredMenuBar
        } onChange: { [weak self] in
            Task { @MainActor in self?.observePrefs() }
        }
    }

    // MARK: Menüleiste

    func updateLabel() {
        guard let button = statusItem.button else { return }
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let label = MenuBarLabel(monitor: monitor, prefs: prefs, darkMenuBar: dark)
        let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let renderKey = label.renderKey + ";\(scale)"
        guard renderKey != lastRenderKey || button.image == nil else { return }
        lastRenderKey = renderKey
        let renderer = ImageRenderer(content: label)
        renderer.scale = scale
        guard let image = renderer.nsImage else { return }
        image.isTemplate = !prefs.coloredMenuBar
        button.image = image
        let summary = prefs.menuBarMetrics.map(\.title).joined(separator: ", ")
        if summary != lastLabelKey {
            lastLabelKey = summary
            button.toolTip = "Puls – " + (summary.isEmpty ? "Systemmonitor" : summary)
        }
    }

    // MARK: Panel

    private func makePanel() -> GlassPanel {
        let root = PanelRootView()
            .environment(monitor)
            .environment(prefs)
            .environment(state)
        return GlassPanel(rootView: root)
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            panel.isVisible ? closePanel() : openPanel()
        }
    }

    func openPanel(route: Route? = nil) {
        if let route { state.route = route }
        guard !monitor.isPanelVisible else { return }
        positionPanel()
        monitor.isPanelVisible = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        statusItem.button?.highlight(true)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // Escape
            self?.closePanel()
            return nil
        }
    }

    func closePanel() {
        guard panel.isVisible else { return }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
        monitor.isPanelVisible = false
        statusItem.button?.highlight(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.monitor.isPanelVisible else { return }
                self.panel.orderOut(nil)
                self.state.route = .overview
            }
        })
    }

    private func positionPanel() {
        guard let buttonWindow = statusItem.button?.window else { return }
        let anchor = buttonWindow.frame
        let screen = buttonWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: PanelMetrics.width, height: PanelMetrics.height)
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = anchor.minY - size.height - 6
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    // MARK: Kontextmenü

    private func showMenu() {
        closePanel()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("Puls öffnen", #selector(menuOpen)))
        menu.addItem(item("Einstellungen …", #selector(menuSettings), key: ","))
        menu.addItem(item("Aktivitätsanzeige öffnen", #selector(menuActivity)))
        menu.addItem(.separator())
        menu.addItem(item("Puls beenden", #selector(menuQuit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in self.statusItem.menu = nil }
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func menuOpen() { openPanel(route: .overview) }
    @objc private func menuSettings() { openPanel(route: .settings) }
    @objc private func menuActivity() { Actions.openActivityMonitor() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}
