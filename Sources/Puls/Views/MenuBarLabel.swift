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

/// Inhalt des Menüleisten-Symbols. Einfarbig wird es als Vorlagenbild gerendert (macOS färbt es passend
/// zur Menüleiste), farbig mit Ampel-Indikatoren und Textfarbe passend zur hellen bzw. dunklen Menüleiste.
struct MenuBarLabel: View {
    let monitor: SystemMonitor
    let prefs: Preferences
    var darkMenuBar = false

    private var colored: Bool { prefs.coloredMenuBar }
    private var ink: Color { colored && darkMenuBar ? .white : .black }

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
        .foregroundStyle(ink)
    }

    @ViewBuilder private func item(_ metric: MenuBarMetric) -> some View {
        switch metric {
        case .cpu:
            gaugeItem(caption: "CPU", text: Fmt.percent(monitor.cpu.total),
                      fill: monitor.cpu.total, color: Self.loadColor(monitor.cpu.total))
        case .gpu:
            let value = monitor.gpu?.utilization ?? 0
            gaugeItem(caption: "GPU", text: Fmt.percent(value), fill: value, color: Self.loadColor(value))
        case .memory:
            gaugeItem(caption: "RAM", text: Fmt.percent(monitor.memory.usedPercent),
                      fill: monitor.memory.usedPercent, color: Self.pressureColor(monitor.memory.pressure))
        case .network:
            VStack(alignment: .trailing, spacing: -1) {
                HStack(spacing: 2) {
                    Text(Fmt.compactRate(monitor.network.upload))
                    Image(systemName: "arrow.up").font(.system(size: 7, weight: .black))
                        .foregroundStyle(colored ? Theme.upload : ink)
                }
                HStack(spacing: 2) {
                    Text(Fmt.compactRate(monitor.network.download))
                    Image(systemName: "arrow.down").font(.system(size: 7, weight: .black))
                        .foregroundStyle(colored ? Theme.download : ink)
                }
            }
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .frame(width: 62, alignment: .trailing)
        case .disk:
            let volume = monitor.volumes.first
            gaugeItem(caption: "SSD", text: volume.map { Fmt.storage($0.available) } ?? "–",
                      fill: volume?.usedPercent ?? 0, color: Self.loadColor(volume?.usedPercent ?? 0), width: 42)
        case .temperature:
            let t = monitor.sensors.headline
            gaugeItem(caption: "TEMP",
                      text: t.map { Fmt.temperature($0, fahrenheit: prefs.useFahrenheit) } ?? "–",
                      fill: t.map { ($0 - 25) / 75 * 100 } ?? 0,
                      color: t.map(Theme.temperature) ?? .green, width: 30)
        case .battery:
            let b = monitor.battery
            HStack(spacing: 3) {
                Image(systemName: b?.symbolName ?? "battery.100percent")
                    .font(.system(size: 13, weight: .regular))
                    .symbolRenderingMode(colored ? .palette : .monochrome)
                    .foregroundStyle(colored ? Theme.battery(b?.percent ?? 100, charging: b?.isCharging ?? false) : ink, ink.opacity(0.5))
                Text(Fmt.percent(b?.percent ?? 0))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
        }
    }

    /// Beschriftung + Wert, daneben ein kleiner Füllbalken als Ampel-Indikator.
    private func gaugeItem(caption: String, text: String, fill: Double, color: Color, width: CGFloat = 29) -> some View {
        HStack(spacing: 4) {
            twoLine(caption: caption, value: text, width: width)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5).fill(ink.opacity(0.22))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(colored ? AnyShapeStyle(color) : AnyShapeStyle(ink))
                    .frame(height: max(2, 16 * min(max(fill, 0), 100) / 100))
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

    /// Fasst alles sichtbar Angezeigte zusammen; ist er unverändert, muss nicht neu gezeichnet werden.
    var renderKey: String {
        var parts = ["\(darkMenuBar)", "\(colored)"]
        for metric in prefs.menuBarMetrics {
            switch metric {
            case .cpu: parts.append("c\(Int(monitor.cpu.total.rounded()))")
            case .gpu: parts.append("g\(Int((monitor.gpu?.utilization ?? 0).rounded()))")
            case .memory: parts.append("m\(Int(monitor.memory.usedPercent.rounded()))\(monitor.memory.pressure.rawValue)")
            case .network: parts.append("n\(Fmt.compactRate(monitor.network.upload))|\(Fmt.compactRate(monitor.network.download))")
            case .disk: parts.append("d" + (monitor.volumes.first.map { Fmt.storage($0.available) + "\(Int($0.usedPercent))" } ?? "-"))
            case .temperature: parts.append("t" + (monitor.sensors.headline.map { Fmt.temperature($0, fahrenheit: prefs.useFahrenheit) } ?? "-"))
            case .battery:
                let b = monitor.battery
                parts.append("b\(Int((b?.percent ?? 0).rounded()))\(b?.isCharging ?? false)\(b?.symbolName ?? "")")
            }
        }
        return parts.joined(separator: ";")
    }

    static func loadColor(_ percent: Double) -> Color {
        switch percent {
        case ..<60: Color(red: 0.20, green: 0.80, blue: 0.35)
        case ..<85: Color(red: 1.00, green: 0.78, blue: 0.10)
        default: Color(red: 1.00, green: 0.27, blue: 0.23)
        }
    }

    static func pressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: loadColor(0)
        case .warning: loadColor(70)
        case .critical: loadColor(100)
        }
    }
}
