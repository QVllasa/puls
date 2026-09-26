import Foundation
import ServiceManagement

enum ServiceManagementStatus {
    static func describe() -> String {
        switch SMAppService.mainApp.status {
        case .enabled: "enabled"
        case .notRegistered: "not registered"
        case .requiresApproval: "requires approval"
        case .notFound: "not found"
        @unknown default: "unknown"
        }
    }
}

/// `Puls --dump` prints all readings as text (diagnostics without UI).
enum Dump {
    static func run() {
        let cpu = CPUSampler()
        let net = NetworkSampler()
        let disk = DiskSampler()
        let sensors = SensorSampler()
        _ = cpu.sample(); _ = net.sample(); _ = disk.sampleThroughput()
        Thread.sleep(forTimeInterval: 0.3)
        _ = cpu.sample()
        Thread.sleep(forTimeInterval: 1)

        let info = MachineInfo.current
        print("Login item status:", ServiceManagementStatus.describe())
        print("Mac:", info.computerName, "|", info.chip, "|", info.modelIdentifier, "|", info.osVersion)
        if let c = cpu.sample() {
            print(String(format: "CPU: %.1f%% (user %.1f, sys %.1f) load %.2f %.2f %.2f", c.total, c.user, c.system, c.load[0], c.load[1], c.load[2]))
            for g in cpu.groups {
                print("  \(g.name) \(g.range):", g.range.map { $0 < c.cores.count ? String(format: "%.0f", c.cores[$0]) : "–" }.joined(separator: " "))
            }
        }
        if let g = GPUSampler.sample() { print("GPU:", g.name, g.coreCount ?? -1, "cores,", g.utilization, "%, mem", g.memoryInUse) }
        if let m = MemorySampler.sample() {
            print("RAM:", m.used >> 20, "MB of", m.total >> 20, "MB | app", m.app >> 20, "wired", m.wired >> 20, "compr", m.compressed >> 20, "cache", m.cached >> 20, "| swap", m.swapUsed >> 20, "| pressure", m.pressure.label, m.pressurePercent)
        }
        let n = net.sample()
        print("Network:", n.interfaceKind, n.interfaceName ?? "-", n.localIPv4 ?? "-", "↓", Int(n.download), "↑", Int(n.upload), "total", n.totalReceived >> 20, n.totalSent >> 20)
        let d = disk.sampleThroughput()
        print("Disk: r", Int(d.read), "w", Int(d.write))
        for v in DiskSampler.volumes() { print("  Volume:", v.name, v.path, v.total / 1_000_000_000, "GB, free", v.available / 1_000_000_000) }
        let s = sensors.sample()
        print("Sensors: CPU", s.cpu ?? -1, "max", s.cpuMax ?? -1, "GPU", s.gpu ?? -1, "battery", s.battery ?? -1, "SSD", s.ssd ?? -1, "power", s.systemPower ?? -1)
        for f in s.fans { print("  Fan", f.id, f.rpm, f.min, f.max) }
        for r in s.all { print("  ", r.name, String(format: "%.1f", r.value)) }
        if let b = BatterySampler.sample() {
            print("Battery:", b.percent, b.stateLabel, b.minutesRemaining ?? -1, "min, cycles", b.cycleCount ?? -1, "health", b.health ?? -1, "temp", b.temperature ?? -1, "W", b.power ?? 0, "adapter", b.adapterWatts ?? -1, b.condition ?? "")
        }
        let p = ProcessSampler.sample()
        print("Top CPU:", p.cpu.map { "\($0.name) \($0.cpu)" })
        print("Top memory:", p.memory.map { "\($0.name) \($0.memory >> 20)MB" })
        print("Bluetooth:", BluetoothSampler.sample().map { "\($0.name) [\($0.kind)] \($0.levels.map { "\($0.label)\($0.percent)" })" })
    }
}
