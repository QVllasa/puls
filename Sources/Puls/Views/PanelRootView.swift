import SwiftUI

enum Route: Hashable {
    case overview
    case detail(Module)
    case settings
}

@MainActor
@Observable
final class PanelState {
    var route: Route = .overview
    var close: () -> Void = {}

    func go(_ route: Route) {
        withAnimation(.smooth(duration: 0.32)) { self.route = route }
    }
}

struct PanelRootView: View {
    @Environment(PanelState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            PanelHeader()
            ZStack(alignment: .top) {
                switch state.route {
                case .overview:
                    OverviewView().transition(.opacity.combined(with: .scale(scale: 0.97)))
                case .detail(let module):
                    ScrollView {
                        DetailView(module: module).padding(.bottom, 2)
                    }
                    .scrollIndicators(.never)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                case .settings:
                    ScrollView { SettingsView() }
                        .scrollIndicators(.never)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(14)
        .frame(width: PanelMetrics.width, height: PanelMetrics.height, alignment: .top)
        .onExitCommand { state.close() }
    }
}

struct PanelHeader: View {
    @Environment(PanelState.self) private var state
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(spacing: 10) {
            switch state.route {
            case .overview:
                AppGlyph()
                VStack(alignment: .leading, spacing: 1) {
                    Text(monitor.machine.computerName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(monitor.machine.chip) · \(Fmt.memory(monitor.machine.physicalMemory)) · seit \(Fmt.uptime(monitor.uptime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 4)
                GlassIconButton(symbol: "gearshape", help: "Einstellungen") { state.go(.settings) }
            case .detail(let module):
                GlassIconButton(symbol: "chevron.left", help: "Zurück") { state.go(.overview) }
                Image(systemName: module.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(module.tint.gradient)
                Text(module.title).font(.title3.weight(.semibold))
                Spacer()
                if module == .cpu || module == .memory {
                    GlassIconButton(symbol: "waveform.path.ecg.rectangle", help: "Aktivitätsanzeige öffnen") {
                        Actions.openActivityMonitor(); state.close()
                    }
                }
            case .settings:
                GlassIconButton(symbol: "chevron.left", help: "Zurück") { state.go(.overview) }
                Text("Einstellungen").font(.title3.weight(.semibold))
                Spacer()
            }
        }
        .frame(height: 38)
    }
}

struct GlassIconButton: View {
    var symbol: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }
}

struct AppGlyph: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.62, green: 0.36, blue: 0.98)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .purple.opacity(0.3), radius: 6, y: 2)
    }
}

enum Actions {
    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func openBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openNetworkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func reveal(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
