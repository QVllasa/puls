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

    var body: some View {
        let items = modules
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        ScrollView {
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
            .scaleEffect(hovering ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.snappy(duration: 0.18)) { hovering = h } }
        .accessibilityLabel("\(module.title): \(value)")
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
            guard let t = monitor.sensors.headline else { return "–" }
            return Fmt.temperature(t, fahrenheit: prefs.useFahrenheit)
        case .battery: return Fmt.percent(monitor.battery?.percent ?? 0)
        }
    }

    private var subtitle: String? {
        switch module {
        case .cpu:
            return "Last \(Fmt.load(monitor.cpu.load[0])) · \(monitor.cpu.cores.count) Kerne"
        case .gpu:
            return monitor.gpu.map { "\(Fmt.memory($0.memoryInUse)) belegt" }
        case .memory:
            return "\(Fmt.memory(monitor.memory.used)) von \(Fmt.memory(monitor.memory.total))"
        case .network:
            return monitor.network.isConnected ? "↑ \(Fmt.rate(monitor.network.upload))" : "Keine Verbindung"
        case .disk:
            return monitor.volumes.first.map { "frei · \($0.name)" }
        case .sensors:
            var parts: [String] = []
            if let fan = monitor.sensors.fans.first { parts.append(fan.rpm > 0 ? Fmt.rpm(fan.rpm) : "Lüfter aus") }
            if let p = monitor.sensors.systemPower { parts.append(Fmt.watts(p)) }
            return parts.isEmpty ? "CPU" : parts.joined(separator: " · ")
        case .battery:
            guard let b = monitor.battery else { return nil }
            if let minutes = b.minutesRemaining, !b.isFullyCharged {
                return b.stateLabel + " · " + (b.isCharging ? "voll in " : "noch ") + Fmt.minutes(minutes)
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
                    Text("\(Fmt.percent(v.usedPercent)) belegt von \(Fmt.storage(v.total))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .sensors:
            Sparkline(values: monitor.temperatureHistory.values, maxValue: 105, color: module.tint)
        case .battery:
            if let b = monitor.battery {
                VStack { Spacer(minLength: 0); MeterBar(value: b.percent, color: Theme.battery(b.percent, charging: b.isCharging), height: 7) }
            }
        }
    }
}
