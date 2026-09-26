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
                BigValue(value: Fmt.percent(cpu.total), caption: "Total load",
                         color: Theme.level(cpu.total, base: .primary))
                Spacer()
                RingGauge(value: cpu.total, color: Module.cpu.tint, lineWidth: 7).frame(width: 46, height: 46)
            }
            Sparkline(values: monitor.cpuHistory.values, maxValue: 100, color: Module.cpu.tint).frame(height: 64)
            HStack {
                LegendValue(label: "User", value: Fmt.percent(cpu.user), color: .blue)
                LegendValue(label: "System", value: Fmt.percent(cpu.system), color: .red)
                LegendValue(label: "Idle", value: Fmt.percent(cpu.idle), color: .gray)
            }
        }
        SectionCard(title: "Cores", trailing: String(localized: "\(cpu.cores.count) total")) {
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
        SectionCard(title: "System load") {
            HStack {
                LegendValue(label: "1 min", value: Fmt.load(cpu.load[0]), color: .blue)
                LegendValue(label: "5 min", value: Fmt.load(cpu.load[1]), color: .blue.opacity(0.7))
                LegendValue(label: "15 min", value: Fmt.load(cpu.load[2]), color: .blue.opacity(0.45))
            }
            InfoRow(label: "Up for", value: Fmt.uptime(monitor.uptime))
        }
        if Flavor.hasProcesses {
            SectionCard(title: "Processes", trailing: "by CPU") {
                ProcessList(rows: monitor.topCPU, mode: .cpu)
            }
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
                BigValue(value: Fmt.percent(gpu.utilization), caption: "Utilization",
                         color: Theme.level(gpu.utilization, base: .primary))
                Spacer()
                RingGauge(value: gpu.utilization, color: Module.gpu.tint, lineWidth: 7).frame(width: 46, height: 46)
            }
            Sparkline(values: monitor.gpuHistory.values, maxValue: 100, color: Module.gpu.tint).frame(height: 64)
            HStack {
                LegendValue(label: "Renderer", value: Fmt.percent(gpu.renderer), color: .purple)
                LegendValue(label: "Graphics memory", value: Fmt.memory(gpu.memoryInUse), color: .pink)
            }
        }
        SectionCard(title: "Graphics chip") {
            InfoRow(label: "Model", value: gpu.name)
            if let cores = gpu.coreCount { InfoRow(label: "GPU cores", value: "\(cores)") }
            if let t = monitor.sensors.gpu {
                InfoRow(label: "Temperature", value: Fmt.temperature(t, fahrenheit: prefs.useFahrenheit))
            }
            InfoRow(label: "Memory", value: String(localized: "Shared with system memory"))
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
                BigValue(value: Fmt.memory(m.used), caption: String(localized: "used of \(Fmt.memory(m.total))"))
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
                InfoRow(label: "App memory", value: Fmt.memory(m.app), dot: .mint)
                InfoRow(label: "Wired memory", value: Fmt.memory(m.wired), dot: .blue)
                InfoRow(label: "Compressed", value: Fmt.memory(m.compressed), dot: .orange)
                InfoRow(label: "Cached", value: Fmt.memory(m.cached), dot: .gray.opacity(0.5))
            }
        }
        SectionCard(title: "Memory pressure", trailing: m.pressure.label) {
            MeterBar(value: max(m.pressurePercent, 2), color: pressureColor(m.pressure), height: 8)
            InfoRow(label: "Memory load", value: Fmt.percent(m.pressurePercent))
            InfoRow(label: "Swap used", value: m.swapUsed > 0 ? String(localized: "\(Fmt.memory(m.swapUsed)) of \(Fmt.memory(m.swapTotal))") : String(localized: "None"))
        }
        if Flavor.hasProcesses {
            SectionCard(title: "Processes", trailing: "by memory") {
                ProcessList(rows: monitor.topMemory, mode: .memory)
            }
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
                LegendValue(label: "Peak ↓", value: Fmt.rate(monitor.downloadHistory.max), color: Theme.download)
                LegendValue(label: "Peak ↑", value: Fmt.rate(monitor.uploadHistory.max), color: Theme.upload)
            }
        }
        SectionCard(title: "Connection", trailing: n.interfaceName) {
            InfoRow(label: "Type", value: n.interfaceKind)
            InfoRow(label: "Local IP", value: monitor.displayLocalIP ?? "–", copyable: true)
            if prefs.fetchPublicIP {
                InfoRow(label: "Public IP",
                        value: monitor.displayPublicIP ?? (monitor.publicIPLoading ? String(localized: "Looking up …") : "–"),
                        copyable: monitor.publicIP != nil)
            }
            Button("Network Settings …") { Actions.openNetworkSettings() }
                .buttonStyle(.link)
                .font(.callout)
        }
        SectionCard(title: "Data since startup") {
            HStack {
                LegendValue(label: "Received", value: Fmt.storage(n.totalReceived), color: Theme.download)
                LegendValue(label: "Sent", value: Fmt.storage(n.totalSent), color: Theme.upload)
            }
        }
    }
}

// MARK: - Festplatte

struct DiskDetail: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        SectionCard(title: "Activity") {
            HStack {
                LegendValue(label: "Read", value: Fmt.rate(monitor.disk.read), color: Theme.read)
                LegendValue(label: "Write", value: Fmt.rate(monitor.disk.write), color: Theme.write)
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
                            Text("\(Fmt.storage(volume.available)) free")
                                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                        MeterBar(value: volume.usedPercent, color: Theme.level(volume.usedPercent, base: Module.disk.tint), height: 7)
                        Text("\(Fmt.storage(volume.used)) of \(Fmt.storage(volume.total)) used")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
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
        if s.cpu == nil {
            SectionCard {
                HStack(alignment: .top) {
                    BigValue(value: s.thermalLabel, caption: "Thermal state",
                             color: Theme.temperature(40 + s.thermalLevel * 0.55))
                    Spacer()
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.temperature(40 + s.thermalLevel * 0.55).gradient)
                }
                MeterBar(value: s.thermalLevel, color: Theme.temperature(40 + s.thermalLevel * 0.55), height: 8)
                Text(thermalExplanation(s.thermalState))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = s.battery { InfoRow(label: "Battery temperature", value: temp(t)) }
            }
        } else {
        SectionCard {
            HStack(alignment: .top) {
                BigValue(value: s.cpu.map { temp($0) } ?? "–", caption: "CPU temperature (avg)",
                         color: s.cpu.map(Theme.temperature) ?? .primary)
                Spacer()
                if let max = s.cpuMax {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(temp(max)).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text("hottest core").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Sparkline(values: monitor.temperatureHistory.values, maxValue: 105, color: Module.sensors.tint).frame(height: 56)
            HStack {
                if let t = s.gpu { LegendValue(label: "Graphics", value: temp(t), color: .purple) }
                if let t = s.battery { LegendValue(label: "Battery", value: temp(t), color: .green) }
                if let t = s.ssd { LegendValue(label: "SSD", value: temp(t), color: .indigo) }
            }
            InfoRow(label: "Thermal state", value: s.thermalLabel)
        }
        }
        if !s.fans.isEmpty {
            SectionCard(title: "Fans") {
                ForEach(s.fans) { fan in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "fanblades.fill").foregroundStyle(.cyan.gradient)
                                .rotationEffect(.degrees(fan.rpm > 0 ? 360 : 0))
                            Text(s.fans.count > 1 ? (fan.id == 0 ? String(localized: "Left") : String(localized: "Right")) : String(localized: "Fan"))
                            Spacer()
                            Text(fan.rpm > 0 ? Fmt.rpm(fan.rpm) : String(localized: "Off (passive)"))
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        MeterBar(value: fan.percent, color: .cyan, height: 6)
                    }
                }
            }
        }
        if let power = s.systemPower {
            SectionCard(title: "Power draw") {
                HStack(alignment: .center) {
                    BigValue(value: Fmt.watts(power), caption: "entire system")
                    Spacer()
                    Sparkline(values: monitor.powerHistory.values, color: .yellow).frame(width: 150, height: 40)
                }
            }
        }
        if !s.all.isEmpty {
            SectionCard(title: "All sensors", trailing: "\(s.all.count)") {
                Button {
                    withAnimation(.snappy) { showAll.toggle() }
                } label: {
                    HStack {
                        Text(showAll ? String(localized: "Show less") : String(localized: "Show all temperature sensors"))
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

    private func thermalExplanation(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: String(localized: "Your Mac is running within its normal temperature range.")
        case .fair: String(localized: "Your Mac is getting warmer. The fans may spin up.")
        case .serious: String(localized: "Your Mac is hot and may be reducing performance.")
        case .critical: String(localized: "Your Mac is very hot and is significantly reducing performance.")
        @unknown default: ""
        }
    }
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
                            Text(b.isCharging ? String(localized: "Full in \(Fmt.minutes(minutes))") : String(localized: "\(Fmt.minutes(minutes)) remaining"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            SectionCard(title: "Health") {
                if let health = b.health {
                    InfoRow(label: "Maximum capacity", value: Fmt.percent(health))
                }
                if let condition = b.condition {
                    InfoRow(label: "Condition", value: Self.localizedCondition(condition))
                }
                if let cycles = b.cycleCount { InfoRow(label: "Cycle count", value: "\(cycles)") }
                if let t = b.temperature { InfoRow(label: "Temperature", value: Fmt.temperature(t, fahrenheit: prefs.useFahrenheit)) }
                if let power = b.power {
                    InfoRow(label: power > 0 ? "Charging power" : "Power usage", value: Fmt.watts(power))
                }
                if let adapter = b.adapterWatts { InfoRow(label: "Power adapter", value: "\(adapter)\u{202F}W") }
                Button("Battery Settings …") { Actions.openBatterySettings() }
                    .buttonStyle(.link)
                    .font(.callout)
            }
        }
        SectionCard(title: "Bluetooth devices") {
            if monitor.bluetooth.isEmpty {
                HStack(spacing: 8) {
                    if !monitor.bluetoothLoaded { ProgressView().controlSize(.small) }
                    Text(monitor.bluetoothLoaded ? String(localized: "No connected devices report a battery level") : String(localized: "Loading …"))
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
        case "good", "normal": String(localized: "Good")
        case "fair": String(localized: "Fair")
        case "poor": String(localized: "Poor")
        case "check battery", "service battery", "service recommended": String(localized: "Service recommended")
        default: raw
        }
    }
}
