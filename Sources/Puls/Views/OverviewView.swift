import SwiftUI

struct OverviewView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(PanelState.self) private var state

    private var modules: [Module] {
        Module.allCases.filter { module in
            switch module {
            case .gpu: monitor.gpu != nil
            case .battery: monitor.battery != nil
            default: true
            }
        }
    }

    @Environment(Preferences.self) private var prefs

    var body: some View {
        let items = modules
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        ScrollView {
            if Flavor.isAppStore && !prefs.loginItemQuestionAnswered {
                LoginItemPrompt().padding(.bottom, 10)
            }
            if let update = UpdateChecker.shared.available {
                UpdateBanner(version: update.version).padding(.bottom, 10)
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row) { module in
                            Tile(module: module, wide: row.count == 1) { state.go(.detail(module)) }
                                .gridCellColumns(row.count == 1 ? 2 : 1)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct Tile: View {
    var module: Module
    var wide = false
    var action: () -> Void
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var prefs
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(module.tint.gradient)
                        .frame(width: 16)
                    Text(module.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .opacity(hovering ? 1 : 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if wide, let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if !wide, let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                chart.frame(height: 26)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .card(highlighted: hovering)
            .scaleEffect(hovering && !reduceMotion ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.snappy(duration: 0.18)) { hovering = h } }
        .accessibilityLabel("\(module.title): \(value)")
        .accessibilityValue(subtitle ?? "")
        .accessibilityHint(Text("Shows details"))
    }

    private var symbol: String {
        if module == .battery, let b = monitor.battery { return b.symbolName }
        return module.symbol
    }

    private var value: String {
        switch module {
        case .cpu: return Fmt.percent(monitor.cpu.total)
        case .gpu: return Fmt.percent(monitor.gpu?.utilization ?? 0)
        case .memory: return Fmt.percent(monitor.memory.usedPercent)
        case .network: return "↓ " + Fmt.rate(monitor.network.download)
        case .disk:
            guard let v = monitor.volumes.first else { return "–" }
            return Fmt.storage(v.available)
        case .sensors:
            guard let t = monitor.sensors.headline else { return monitor.sensors.thermalLabel }
            return Fmt.temperature(t, fahrenheit: prefs.useFahrenheit)
        case .battery: return Fmt.percent(monitor.battery?.percent ?? 0)
        }
    }

    private var subtitle: String? {
        switch module {
        case .cpu:
            return String(localized: "Load \(Fmt.load(monitor.cpu.load[0])) · \(monitor.cpu.cores.count) cores")
        case .gpu:
            return monitor.gpu.map { String(localized: "\(Fmt.memory($0.memoryInUse)) in use") }
        case .memory:
            return String(localized: "\(Fmt.memory(monitor.memory.used)) of \(Fmt.memory(monitor.memory.total))")
        case .network:
            return monitor.network.isConnected ? "↑ \(Fmt.rate(monitor.network.upload))" : String(localized: "Not connected")
        case .disk:
            return monitor.volumes.first.map { String(localized: "free · \($0.name)") }
        case .sensors:
            var parts: [String] = []
            if monitor.sensors.headline == nil, let t = monitor.sensors.battery {
                parts.append(String(localized: "Battery \(Fmt.temperature(t, fahrenheit: prefs.useFahrenheit))"))
            }
            if let fan = monitor.sensors.fans.first { parts.append(fan.rpm > 0 ? Fmt.rpm(fan.rpm) : String(localized: "Fans off")) }
            if let p = monitor.sensors.systemPower { parts.append(Fmt.watts(p)) }
            return parts.isEmpty ? String(localized: "Thermal state") : parts.joined(separator: " · ")
        case .battery:
            guard let b = monitor.battery else { return nil }
            if let minutes = b.minutesRemaining, !b.isFullyCharged {
                return b.stateLabel + " · " + (b.isCharging ? String(localized: "full in \(Fmt.minutes(minutes))") : String(localized: "\(Fmt.minutes(minutes)) left"))
            }
            return b.stateLabel
        }
    }

    @ViewBuilder private var chart: some View {
        switch module {
        case .cpu:
            Sparkline(values: monitor.cpuHistory.values, maxValue: 100, color: module.tint)
        case .gpu:
            Sparkline(values: monitor.gpuHistory.values, maxValue: 100, color: module.tint)
        case .memory:
            Sparkline(values: monitor.memoryHistory.values, maxValue: 100, color: module.tint)
        case .network:
            MirrorChart(top: monitor.downloadHistory.values, bottom: monitor.uploadHistory.values,
                        topColor: Theme.download, bottomColor: Theme.upload)
        case .disk:
            if let v = monitor.volumes.first {
                VStack(alignment: .leading, spacing: 5) {
                    Spacer(minLength: 0)
                    MeterBar(value: v.usedPercent, color: module.tint, height: 7)
                    Text("\(Fmt.percent(v.usedPercent)) used of \(Fmt.storage(v.total))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .sensors:
            if monitor.sensors.headline != nil {
                Sparkline(values: monitor.temperatureHistory.values, maxValue: 105, color: module.tint)
            } else {
                Sparkline(values: monitor.powerHistory.values, color: .yellow)
            }
        case .battery:
            if let b = monitor.battery {
                VStack { Spacer(minLength: 0); MeterBar(value: b.percent, color: Theme.battery(b.percent, charging: b.isCharging), height: 7) }
            }
        }
    }
}

/// Einmalige Frage in der Store-Version, ob Puls mit dem Mac starten soll.
struct LoginItemPrompt: View {
    @Environment(Preferences.self) private var prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green.gradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open at login?").font(.callout.weight(.semibold))
                    Text("Puls will then start automatically in the menu bar every time you log in.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("No thanks") { answer(false) }
                    .buttonStyle(.glass)
                Button("Open at login") { answer(true) }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .card()
    }

    private func answer(_ enable: Bool) {
        withAnimation(.snappy) {
            prefs.launchAtLogin = enable
            prefs.loginItemQuestionAnswered = true
        }
    }
}

/// Hinweis auf eine neuere Version (nur GitHub-Version).
struct UpdateBanner: View {
    var version: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.blue.gradient)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Puls \(version) is available").font(.callout.weight(.semibold))
                Text("You are using version \(Bundle.main.shortVersion).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Download") { UpdateChecker.shared.openDownload() }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
        }
        .padding(12)
        .card()
        .accessibilityElement(children: .combine)
    }
}
