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
    private var localMonitor: Any?
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
            button.setAccessibilityLabel(String(localized: "Puls system monitor"))
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
        button.setAccessibilityValue(accessibilitySummary())
        let summary = prefs.menuBarMetrics.map(\.title).joined(separator: ", ")
        if summary != lastLabelKey {
            lastLabelKey = summary
            button.toolTip = "Puls – " + (summary.isEmpty ? String(localized: "System monitor") : summary)
        }
    }

    private func accessibilitySummary() -> String {
        prefs.menuBarMetrics.map { metric -> String in
            switch metric {
            case .cpu: "\(metric.title) \(Fmt.percent(monitor.cpu.total))"
            case .gpu: "\(metric.title) \(Fmt.percent(monitor.gpu?.utilization ?? 0))"
            case .memory: "\(metric.title) \(Fmt.percent(monitor.memory.usedPercent))"
            case .network: String(localized: "Download \(Fmt.rate(monitor.network.download)), upload \(Fmt.rate(monitor.network.upload))")
            case .disk: "\(metric.title) \(monitor.volumes.first.map { Fmt.storage($0.available) } ?? "–")"
            case .temperature: "\(metric.title) \(monitor.sensors.headline.map { Fmt.temperature($0, fahrenheit: prefs.useFahrenheit) } ?? "–")"
            case .battery: "\(metric.title) \(Fmt.percent(monitor.battery?.percent ?? 0))"
            }
        }.joined(separator: ", ")
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
            return
        }
        // Ein Klick auf einen Wert öffnet dessen Detailansicht, bei offenem Panel wechselt er dorthin.
        // Zeigt das Panel diese Ansicht schon, schließt der Klick es wieder.
        let route = clickedRoute(sender)
        if !panel.isVisible {
            openPanel(route: route)
        } else if state.route == route {
            closePanel()
        } else {
            state.route = route
        }
    }

    /// Die Detailansicht des Werts unter dem Mauszeiger, ohne Werte in der Menüleiste die Übersicht.
    /// Die Position kommt von der Maus, nicht vom Ereignis: macOS 27 meldet jeden Klick auf ein
    /// Menüleistensymbol in dessen Mitte.
    private func clickedRoute(_ button: NSStatusBarButton) -> Route {
        guard let image = button.image, let onScreen = buttonFrameOnScreen() else { return .overview }
        let label = MenuBarLabel(monitor: monitor, prefs: prefs)
        let x = MenuBarLabel.imageX(mouseX: NSEvent.mouseLocation.x, button: onScreen, imageWidth: image.size.width)
        guard let index = MenuBarLabel.segment(at: x, widths: label.itemWidths()) else { return .overview }
        return .detail(prefs.menuBarMetrics[index].module)
    }

    private func buttonFrameOnScreen() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
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
            let mouse = NSEvent.mouseLocation
            Task { @MainActor in
                // Seit macOS 27 zeichnet ein anderer Prozess die Menüleiste; ein Klick auf das eigene
                // Symbol kommt dann hier an. Den behandelt buttonClicked, er ist kein Klick daneben.
                guard let self, !(self.statusItem.button?.window?.frame.contains(mouse) ?? false) else { return }
                self.closePanel()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            // Escape, oder ein Klick in den durchsichtigen Schattenrand, zählt als Klick daneben.
            let escape = event.type == .keyDown && event.keyCode == 53
            let margin = event.type != .keyDown && event.window === self.panel
                && self.panel.isInShadowMargin(event.locationInWindow)
            guard escape || margin else { return event }
            self.closePanel()
            return nil
        }
    }

    func closePanel() {
        guard panel.isVisible else { return }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        outsideClickMonitor = nil
        localMonitor = nil
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
        panel.setFrame(PanelMetrics.windowFrame(below: anchor, in: visible), display: true)
    }

    // MARK: Kontextmenü

    private func showMenu() {
        closePanel()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item(String(localized: "Open Puls"), #selector(menuOpen)))
        menu.addItem(item(String(localized: "Settings …"), #selector(menuSettings), key: ","))
        menu.addItem(item(String(localized: "Open Activity Monitor"), #selector(menuActivity)))
        if let update = UpdateChecker.shared.available {
            menu.addItem(item(String(localized: "Download Puls \(update.version) …"), #selector(menuUpdate)))
        }
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit Puls"), #selector(menuQuit), key: "q"))
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
    @objc private func menuUpdate() { UpdateChecker.shared.openDownload() }
}
