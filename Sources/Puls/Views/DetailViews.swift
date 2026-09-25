import SwiftUI

struct DetailView: View {
    var module: Module

    var body: some View {
        VStack(spacing: 10) {
            switch module {
            case .cpu: CPUDetail()
            case .gpu: GPUDetail()
            case .memory: MemoryDetail()
            case .network: NetworkDetail()
            case .disk: DiskDetail()
            case .sensors: SensorsDetail()
            case .battery: BatteryDetail()
            }
        }
    }
}

// MARK: - CPU

struct CPUDetail: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.cpu
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: Fmt.percent(cpu.total), caption: "Auslastung gesamt",
                         color: Theme.level(cpu.total, base: .primary))
                Spacer()
                RingGauge(value: cpu.total, color: Module.cpu.tint, lineWidth: 7).frame(width: 46, height: 46)
            }
            Sparkline(values: monitor.cpuHistory.values, maxValue: 100, color: Module.cpu.tint).frame(height: 64)
            HStack {
                LegendValue(label: "Nutzer", value: Fmt.percent(cpu.user), color: .blue)
                LegendValue(label: "System", value: Fmt.percent(cpu.system), color: .red)
                LegendValue(label: "Leerlauf", value: Fmt.percent(cpu.idle), color: .gray)
            }
        }
        SectionCard(title: "Kerne", trailing: "\(cpu.cores.count) insgesamt") {
            ForEach(monitor.coreGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(group.name).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.percent(average(group))).font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    CoreBars(values: values(group), color: Module.cpu.tint, height: 30)
                }
            }
        }
        SectionCard(title: "Systemlast") {
            HStack {
                LegendValue(label: "1 Min", value: Fmt.load(cpu.load[0]), color: .blue)
                LegendValue(label: "5 Min", value: Fmt.load(cpu.load[1]), color: .blue.opacity(0.7))
                LegendValue(label: "15 Min", value: Fmt.load(cpu.load[2]), color: .blue.opacity(0.45))
            }
            InfoRow(label: "Eingeschaltet seit", value: Fmt.uptime(monitor.uptime))
        }
        SectionCard(title: "Prozesse", trailing: "nach CPU") {
            ProcessList(rows: monitor.topCPU, mode: .cpu)
        }
    }

    private func values(_ group: CoreGroup) -> [Double] {
        group.range.map { $0 < monitor.cpu.cores.count ? monitor.cpu.cores[$0] : 0 }
    }

    private func average(_ group: CoreGroup) -> Double {
        let v = values(group)
        return v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count)
    }
}

// MARK: - GPU

struct GPUDetail: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var prefs

    var body: some View {
        let gpu = monitor.gpu ?? GPUStats()
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: Fmt.percent(gpu.utilization), caption: "Auslastung",
                         color: Theme.level(gpu.utilization, base: .primary))
                Spacer()
                RingGauge(value: gpu.utilization, color: Module.gpu.tint, lineWidth: 7).frame(width: 46, height: 46)
            }
            Sparkline(values: monitor.gpuHistory.values, maxValue: 100, color: Module.gpu.tint).frame(height: 64)
            HStack {
                LegendValue(label: "Renderer", value: Fmt.percent(gpu.renderer), color: .purple)
                LegendValue(label: "Grafikspeicher", value: Fmt.memory(gpu.memoryInUse), color: .pink)
            }
        }
        SectionCard(title: "Grafikchip") {
            InfoRow(label: "Modell", value: gpu.name)
            if let cores = gpu.coreCount { InfoRow(label: "GPU-Kerne", value: "\(cores)") }
            if let t = monitor.sensors.gpu {
                InfoRow(label: "Temperatur", value: Fmt.temperature(t, fahrenheit: prefs.useFahrenheit))
            }
            InfoRow(label: "Speicher", value: "Gemeinsam mit dem Arbeitsspeicher")
        }
    }
}

// MARK: - Speicher

struct MemoryDetail: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let m = monitor.memory
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: Fmt.memory(m.used), caption: "belegt von \(Fmt.memory(m.total))")
                Spacer()
                ZStack {
                    RingGauge(value: m.usedPercent, color: Module.memory.tint, lineWidth: 7)
                    Text(Fmt.percent(m.usedPercent)).font(.caption2.weight(.bold)).monospacedDigit()
                }
                .frame(width: 50, height: 50)
            }
            Sparkline(values: monitor.memoryHistory.values, maxValue: 100, color: Module.memory.tint).frame(height: 44)
            SegmentBar(segments: [
                .init(id: "app", value: Double(m.app), color: .mint),
                .init(id: "wired", value: Double(m.wired), color: .blue),
                .init(id: "compressed", value: Double(m.compressed), color: .orange),
            ], total: Double(m.total))
            VStack(spacing: 7) {
                InfoRow(label: "App-Speicher", value: Fmt.memory(m.app), dot: .mint)
                InfoRow(label: "Fester Speicher", value: Fmt.memory(m.wired), dot: .blue)
                InfoRow(label: "Komprimiert", value: Fmt.memory(m.compressed), dot: .orange)
                InfoRow(label: "Im Cache", value: Fmt.memory(m.cached), dot: .gray.opacity(0.5))
            }
        }
        SectionCard(title: "Speicherdruck", trailing: m.pressure.label) {
            MeterBar(value: max(m.pressurePercent, 2), color: pressureColor(m.pressure), height: 8)
            InfoRow(label: "Auslastung des Speichers", value: Fmt.percent(m.pressurePercent))
            InfoRow(label: "Auslagerung (Swap)", value: m.swapUsed > 0 ? "\(Fmt.memory(m.swapUsed)) von \(Fmt.memory(m.swapTotal))" : "Keine")
        }
        SectionCard(title: "Prozesse", trailing: "nach Speicher") {
            ProcessList(rows: monitor.topMemory, mode: .memory)
        }
    }

    private func pressureColor(_ p: MemoryPressure) -> Color {
        switch p {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }
}

// MARK: - Netzwerk

struct NetworkDetail: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var prefs

    var body: some View {
        let n = monitor.network
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: Fmt.rate(n.download), caption: "Download", color: Theme.download)
                Spacer()
                BigValue(value: Fmt.rate(n.upload), caption: "Upload", color: Theme.upload, alignment: .trailing)
            }
            MirrorChart(top: monitor.downloadHistory.values, bottom: monitor.uploadHistory.values,
                        topColor: Theme.download, bottomColor: Theme.upload)
                .frame(height: 84)
            HStack {
                LegendValue(label: "Spitze ↓", value: Fmt.rate(monitor.downloadHistory.max), color: Theme.download)
                LegendValue(label: "Spitze ↑", value: Fmt.rate(monitor.uploadHistory.max), color: Theme.upload)
            }
        }
        SectionCard(title: "Verbindung", trailing: n.interfaceName) {
            InfoRow(label: "Art", value: n.interfaceKind)
            InfoRow(label: "Lokale IP", value: monitor.displayLocalIP ?? "–", copyable: true)
            if prefs.fetchPublicIP {
                InfoRow(label: "Öffentliche IP",
                        value: monitor.displayPublicIP ?? (monitor.publicIPLoading ? "Wird ermittelt …" : "–"),
                        copyable: monitor.publicIP != nil)
            }
            Button("Netzwerkeinstellungen …") { Actions.openNetworkSettings() }
                .buttonStyle(.link)
                .font(.callout)
        }
        SectionCard(title: "Datenmenge seit Systemstart") {
            HStack {
                LegendValue(label: "Empfangen", value: Fmt.storage(n.totalReceived), color: Theme.download)
                LegendValue(label: "Gesendet", value: Fmt.storage(n.totalSent), color: Theme.upload)
            }
        }
    }
}

// MARK: - Festplatte

struct DiskDetail: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        SectionCard(title: "Aktivität") {
            HStack {
                LegendValue(label: "Lesen", value: Fmt.rate(monitor.disk.read), color: Theme.read)
                LegendValue(label: "Schreiben", value: Fmt.rate(monitor.disk.write), color: Theme.write)
            }
            MirrorChart(top: monitor.readHistory.values, bottom: monitor.writeHistory.values,
                        topColor: Theme.read, bottomColor: Theme.write)
                .frame(height: 72)
        }
        SectionCard(title: "Volumes") {
            ForEach(monitor.volumes) { volume in
                Button { Actions.reveal(path: volume.path) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: volume.isInternal ? "internaldrive.fill" : "externaldrive.fill")
                                .foregroundStyle(Module.disk.tint.gradient)
                            Text(volume.name).font(.callout.weight(.medium))
                            Spacer()
                            Text("\(Fmt.storage(volume.available)) frei")
                                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                        MeterBar(value: volume.usedPercent, color: Theme.level(volume.usedPercent, base: Module.disk.tint), height: 7)
                        Text("\(Fmt.storage(volume.used)) von \(Fmt.storage(volume.total)) belegt")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Im Finder öffnen")
            }
        }
    }
}

// MARK: - Sensoren

struct SensorsDetail: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var prefs
    @State private var showAll = false

    var body: some View {
        let s = monitor.sensors
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: s.cpu.map { temp($0) } ?? "–", caption: "CPU-Temperatur (Ø)",
                         color: s.cpu.map(Theme.temperature) ?? .primary)
                Spacer()
                if let max = s.cpuMax {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(temp(max)).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text("heißester Kern").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Sparkline(values: monitor.temperatureHistory.values, maxValue: 105, color: Module.sensors.tint).frame(height: 56)
            HStack {
                if let t = s.gpu { LegendValue(label: "Grafik", value: temp(t), color: .purple) }
                if let t = s.battery { LegendValue(label: "Akku", value: temp(t), color: .green) }
                if let t = s.ssd { LegendValue(label: "SSD", value: temp(t), color: .indigo) }
            }
        }
        if !s.fans.isEmpty {
            SectionCard(title: "Lüfter") {
                ForEach(s.fans) { fan in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "fanblades.fill").foregroundStyle(.cyan.gradient)
                                .rotationEffect(.degrees(fan.rpm > 0 ? 360 : 0))
                            Text(s.fans.count > 1 ? (fan.id == 0 ? "Links" : "Rechts") : "Lüfter")
                            Spacer()
                            Text(fan.rpm > 0 ? Fmt.rpm(fan.rpm) : "Aus (passiv)")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        MeterBar(value: fan.percent, color: .cyan, height: 6)
                    }
                }
            }
        }
        if let power = s.systemPower {
            SectionCard(title: "Leistungsaufnahme") {
                HStack(alignment: .center) {
                    BigValue(value: Fmt.watts(power), caption: "gesamtes System")
                    Spacer()
                    Sparkline(values: monitor.powerHistory.values, color: .yellow).frame(width: 150, height: 40)
                }
            }
        }
        if !s.all.isEmpty {
            SectionCard(title: "Alle Sensoren", trailing: "\(s.all.count)") {
                Button {
                    withAnimation(.snappy) { showAll.toggle() }
                } label: {
                    HStack {
                        Text(showAll ? "Weniger anzeigen" : "Alle Temperaturfühler anzeigen")
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showAll ? 180 : 0))
                    }
                    .font(.callout)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                if showAll {
                    VStack(spacing: 6) {
                        ForEach(s.all) { reading in
                            InfoRow(label: reading.name, value: temp(reading.value), dot: Theme.temperature(reading.value))
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func temp(_ c: Double) -> String { Fmt.temperature(c, fahrenheit: prefs.useFahrenheit) }
}

// MARK: - Batterie

struct BatteryDetail: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var prefs

    var body: some View {
        if let b = monitor.battery {
            let color = Theme.battery(b.percent, charging: b.isCharging)
            SectionCard {
                HStack(spacing: 14) {
                    ZStack {
                        RingGauge(value: b.percent, color: color, lineWidth: 8)
                        Image(systemName: b.isCharging ? "bolt.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(color.gradient)
                    }
                    .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.percent(b.percent))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(b.stateLabel).font(.callout).foregroundStyle(.secondary)
                        if let minutes = b.minutesRemaining, !b.isFullyCharged {
                            Text((b.isCharging ? "Voll in " : "Noch ") + Fmt.minutes(minutes))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            SectionCard(title: "Zustand") {
                if let health = b.health {
                    InfoRow(label: "Maximale Kapazität", value: Fmt.percent(health))
                }
                if let condition = b.condition {
                    InfoRow(label: "Bewertung", value: Self.localizedCondition(condition))
                }
                if let cycles = b.cycleCount { InfoRow(label: "Ladezyklen", value: "\(cycles)") }
                if let t = b.temperature { InfoRow(label: "Temperatur", value: Fmt.temperature(t, fahrenheit: prefs.useFahrenheit)) }
                if let power = b.power {
                    InfoRow(label: power > 0 ? "Ladeleistung" : "Verbrauch", value: Fmt.watts(power))
                }
                if let adapter = b.adapterWatts { InfoRow(label: "Netzteil", value: "\(adapter)\u{202F}W") }
                Button("Batterie-Einstellungen …") { Actions.openBatterySettings() }
                    .buttonStyle(.link)
                    .font(.callout)
            }
        }
        SectionCard(title: "Bluetooth-Geräte") {
            if monitor.bluetooth.isEmpty {
                HStack(spacing: 8) {
                    if !monitor.bluetoothLoaded { ProgressView().controlSize(.small) }
                    Text(monitor.bluetoothLoaded ? "Keine verbundenen Geräte mit Akkuanzeige" : "Wird geladen …")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            ForEach(monitor.bluetooth) { device in
                HStack(spacing: 10) {
                    Image(systemName: device.symbolName)
                        .font(.system(size: 15))
                        .foregroundStyle(.blue.gradient)
                        .frame(width: 22)
                    Text(device.name).lineLimit(1)
                    Spacer()
                    ForEach(Array(device.levels.enumerated()), id: \.offset) { _, level in
                        HStack(spacing: 3) {
                            if !level.label.isEmpty {
                                Text(level.label).font(.caption2).foregroundStyle(.tertiary)
                            }
                            Text("\(level.percent)\u{202F}%").monospacedDigit()
                                .foregroundStyle(level.percent < 20 ? .red : .secondary)
                        }
                    }
                }
                .font(.callout)
            }
        }
    }
}

extension BatteryDetail {
    static func localizedCondition(_ raw: String) -> String {
        switch raw.lowercased() {
        case "good", "normal": "Gut"
        case "fair": "Mittel"
        case "poor": "Schwach"
        case "check battery", "service battery", "service recommended": "Service empfohlen"
        default: raw
        }
    }
}
