import Foundation
import ServiceManagement

enum ServiceManagementStatus {
    static func describe() -> String {
        switch SMAppService.mainApp.status {
        case .enabled: "aktiv"
        case .notRegistered: "nicht eingetragen"
        case .requiresApproval: "wartet auf Freigabe"
        case .notFound: "nicht gefunden"
        @unknown default: "unbekannt"
        }
    }
}

/// `Puls --dump` gibt alle Messwerte als Text aus (Diagnose ohne Oberfläche).
enum Dump {
    static func run() {
        let cpu = CPUSampler()
        let net = NetworkSampler()
        let disk = DiskSampler()
        let sensors = SensorSampler()
        _ = cpu.sample(); _ = net.sample(); _ = disk.sampleThroughput()
        Thread.sleep(forTimeInterval: 1)

        let info = MachineInfo.current
        print("Anmeldeobjekt-Status:", ServiceManagementStatus.describe())
        print("Mac:", info.computerName, "|", info.chip, "|", info.modelIdentifier, "|", info.osVersion)
        if let c = cpu.sample() {
            print(String(format: "CPU: %.1f%% (user %.1f, sys %.1f) load %.2f %.2f %.2f", c.total, c.user, c.system, c.load[0], c.load[1], c.load[2]))
            for g in cpu.groups {
                print("  \(g.name) \(g.range):", g.range.map { String(format: "%.0f", c.cores[$0]) }.joined(separator: " "))
            }
        }
        if let g = GPUSampler.sample() { print("GPU:", g.name, g.coreCount ?? -1, "Kerne,", g.utilization, "%, mem", g.memoryInUse) }
        if let m = MemorySampler.sample() {
            print("RAM:", m.used >> 20, "MB von", m.total >> 20, "MB | app", m.app >> 20, "wired", m.wired >> 20, "compr", m.compressed >> 20, "cache", m.cached >> 20, "| swap", m.swapUsed >> 20, "| Druck", m.pressure.label, m.pressurePercent)
        }
        let n = net.sample()
        print("Netz:", n.interfaceKind, n.interfaceName ?? "-", n.localIPv4 ?? "-", "↓", Int(n.download), "↑", Int(n.upload), "gesamt", n.totalReceived >> 20, n.totalSent >> 20)
        let d = disk.sampleThroughput()
        print("Disk: r", Int(d.read), "w", Int(d.write))
        for v in DiskSampler.volumes() { print("  Volume:", v.name, v.path, v.total / 1_000_000_000, "GB, frei", v.available / 1_000_000_000) }
        let s = sensors.sample()
        print("Sensoren: CPU", s.cpu ?? -1, "max", s.cpuMax ?? -1, "GPU", s.gpu ?? -1, "Akku", s.battery ?? -1, "SSD", s.ssd ?? -1, "Leistung", s.systemPower ?? -1)
        for f in s.fans { print("  Lüfter", f.id, f.rpm, f.min, f.max) }
        for r in s.all { print("  ", r.name, String(format: "%.1f", r.value)) }
        if let b = BatterySampler.sample() {
            print("Akku:", b.percent, b.stateLabel, b.minutesRemaining ?? -1, "min, Zyklen", b.cycleCount ?? -1, "Zustand", b.health ?? -1, "Temp", b.temperature ?? -1, "W", b.power ?? 0, "Netzteil", b.adapterWatts ?? -1, b.condition ?? "")
        }
        let p = ProcessSampler.sample()
        print("Top CPU:", p.cpu.map { "\($0.name) \($0.cpu)" })
        print("Top RAM:", p.memory.map { "\($0.name) \($0.memory >> 20)MB" })
        print("Bluetooth:", BluetoothSampler.sample().map { "\($0.name) [\($0.kind)] \($0.levels.map { "\($0.label)\($0.percent)" })" })
    }
}
