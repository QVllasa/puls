import SwiftUI

struct MenuBarMetricIcon: View {
    var metric: MenuBarMetric

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint.gradient)
            .frame(width: 18)
    }

    private var symbol: String {
        switch metric {
        case .cpu: Module.cpu.symbol
        case .gpu: Module.gpu.symbol
        case .memory: Module.memory.symbol
        case .network: Module.network.symbol
        case .disk: Module.disk.symbol
        case .temperature: Module.sensors.symbol
        case .battery: Module.battery.symbol
        }
    }

    private var tint: Color {
        switch metric {
        case .cpu: Module.cpu.tint
        case .gpu: Module.gpu.tint
        case .memory: Module.memory.tint
        case .network: Module.network.tint
        case .disk: Module.disk.tint
        case .temperature: Module.sensors.tint
        case .battery: Module.battery.tint
        }
    }
}

/// Inhalt des Menüleisten-Symbols. Wird als Vorlagenbild gerendert, damit es sich
/// automatisch an helle und dunkle Menüleisten anpasst.
struct MenuBarLabel: View {
    let monitor: SystemMonitor
    let prefs: Preferences

    var body: some View {
        HStack(spacing: 9) {
            if prefs.menuBarMetrics.isEmpty {
                Image(systemName: "waveform.path.ecg").font(.system(size: 14, weight: .semibold))
            }
            ForEach(prefs.menuBarMetrics) { metric in
                item(metric)
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 22)
        .foregroundStyle(.black)
    }

    @ViewBuilder private func item(_ metric: MenuBarMetric) -> some View {
        switch metric {
        case .cpu:
            gaugeItem(caption: "CPU", value: monitor.cpu.total, history: monitor.cpuHistory.values)
        case .gpu:
            gaugeItem(caption: "GPU", value: monitor.gpu?.utilization ?? 0, history: monitor.gpuHistory.values)
        case .memory:
            gaugeItem(caption: "RAM", value: monitor.memory.usedPercent, history: nil)
        case .network:
            VStack(alignment: .trailing, spacing: -1) {
                HStack(spacing: 2) {
                    Text(Fmt.compactRate(monitor.network.upload))
                    Image(systemName: "arrow.up").font(.system(size: 7, weight: .black))
                }
                HStack(spacing: 2) {
                    Text(Fmt.compactRate(monitor.network.download))
                    Image(systemName: "arrow.down").font(.system(size: 7, weight: .black))
                }
            }
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .frame(width: 62, alignment: .trailing)
        case .disk:
            twoLine(caption: "SSD", value: monitor.volumes.first.map { Fmt.storage($0.available) } ?? "–", width: 42)
        case .temperature:
            twoLine(caption: "TEMP",
                    value: monitor.sensors.headline.map { Fmt.temperature($0, fahrenheit: prefs.useFahrenheit) } ?? "–",
                    width: 30)
        case .battery:
            HStack(spacing: 3) {
                Image(systemName: monitor.battery?.symbolName ?? "battery.100percent")
                    .font(.system(size: 13, weight: .regular))
                Text(Fmt.percent(monitor.battery?.percent ?? 0))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
        }
    }

    /// Kleine Beschriftung + Wert, daneben ein Mini-Balken (iStat-Stil, aber reduziert).
    private func gaugeItem(caption: String, value: Double, history: [Double]?) -> some View {
        HStack(spacing: 4) {
            twoLine(caption: caption, value: Fmt.percent(value), width: 29)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5).fill(.black.opacity(0.25))
                RoundedRectangle(cornerRadius: 1.5)
                    .frame(height: max(1.5, 16 * min(value, 100) / 100))
            }
            .frame(width: 4, height: 16)
        }
    }

    private func twoLine(caption: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(caption).font(.system(size: 7.5, weight: .bold)).kerning(0.3).opacity(0.75)
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
        .frame(width: width, alignment: .leading)
    }
}
