import CSystem
import Foundation
import IOKit

struct FanInfo: Identifiable, Equatable {
    let id: Int
    var rpm: Double
    var min: Double
    var max: Double
    var percent: Double {
        guard max > min else { return 0 }
        return Swift.max(0, Swift.min(100, (rpm - min) / (max - min) * 100))
    }
}

struct SensorReading: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let value: Double
}

struct SensorStats: Equatable {
    var cpu: Double?          // Ø der CPU-Die-Sensoren
    var cpuMax: Double?
    var gpu: Double?
    var battery: Double?
    var ssd: Double?
    var fans: [FanInfo] = []
    var systemPower: Double?  // Watt, gesamtes System
    var all: [SensorReading] = []

    /// Wichtigster Temperaturwert für Kacheln und Menüleiste.
    var headline: Double? { cpu ?? gpu ?? battery }
}

final class SensorSampler {
    private var smc: io_connect_t = 0
    private var fanCount: Int?

    init() {
        if smc_open(&smc) != 0 { smc = 0 }
    }

    deinit { smc_close(smc) }

    func sample() -> SensorStats {
        var stats = SensorStats()
        let temps = readHIDTemperatures()
        stats.all = temps
            .map { SensorReading(name: Self.friendlyName($0.key), value: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let cpu = temps.filter { Self.isCPU($0.key) }.map(\.value)
        if !cpu.isEmpty {
            stats.cpu = cpu.reduce(0, +) / Double(cpu.count)
            stats.cpuMax = cpu.max()
        }
        let gpu = temps.filter { Self.isGPU($0.key) }.map(\.value)
        if !gpu.isEmpty { stats.gpu = gpu.reduce(0, +) / Double(gpu.count) }
        stats.battery = temps.first { $0.key.localizedCaseInsensitiveContains("battery") }?.value
        let ssd = temps.filter { $0.key.localizedCaseInsensitiveContains("NAND") }.map(\.value)
        if !ssd.isEmpty { stats.ssd = ssd.max() }

        // SMC liefert CPU-Werte, falls HID keine hat (z. B. Intel-Macs).
        if stats.cpu == nil, let t = readSMC("TC0P") ?? readSMC("TC0D") ?? readSMC("Tp01") {
            stats.cpu = t; stats.cpuMax = t
        }
        stats.fans = readFans()
        if let power = readSMC("PSTR"), power > 0, power < 1000 { stats.systemPower = power }
        return stats
    }

    private func readHIDTemperatures() -> [String: Double] {
        guard let dict = hid_copy_temperatures() as? [String: NSNumber] else { return [:] }
        // Mehrfach vorhandene Sensoren mit identischem Namen werden von HID bereits zusammengefasst.
        return dict.mapValues(\.doubleValue).filter { $0.value > 0 && !$0.key.lowercased().contains("tcal") }
    }

    /// „GPU MTR …“ (M1) bzw. „PMU TPxg“ (M2 und neuer) sind Grafik-Fühler.
    private static func isGPU(_ name: String) -> Bool {
        if name.localizedCaseInsensitiveContains("GPU") { return true }
        return name.range(of: #"^PMU TP\d+g$"#, options: .regularExpression) != nil
    }

    private static func isSoC(_ name: String) -> Bool {
        name.range(of: #"^PMU TP\d+s$"#, options: .regularExpression) != nil
    }

    private static func isCPU(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("tdie") || n.contains("acc mtr") || n.contains("soc mtr") || n.contains("cpu")
    }

    static func friendlyName(_ raw: String) -> String {
        let n = raw.lowercased()
        if n.contains("tdie") { return raw.replacingOccurrences(of: "PMU tdie", with: "CPU-Die ") }
        if isGPU(raw), raw.hasPrefix("PMU TP") {
            return "Grafik " + raw.dropFirst(6).filter(\.isNumber)
        }
        if isSoC(raw) { return "SoC " + raw.dropFirst(6).filter(\.isNumber) }
        if n.contains("tdev") { return raw.replacingOccurrences(of: "PMU tdev", with: "Chip ") }
        if n.contains("gas gauge battery") { return "Akku" }
        if n.contains("battery") { return "Akku " + raw.replacingOccurrences(of: "battery", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces) }
        if n.contains("nand") {
            let channel = raw.replacingOccurrences(of: "NAND", with: "").replacingOccurrences(of: "temp", with: "")
                .trimmingCharacters(in: .whitespaces)
            return channel.isEmpty || channel == "CH0" ? "SSD" : "SSD \(channel)"
        }
        if n.contains("pacc mtr") { return raw.replacingOccurrences(of: "pACC MTR Temp Sensor", with: "Leistungskern ") }
        if n.contains("eacc mtr") { return raw.replacingOccurrences(of: "eACC MTR Temp Sensor", with: "Effizienzkern ") }
        if n.contains("gpu mtr") { return raw.replacingOccurrences(of: "GPU MTR Temp Sensor", with: "GPU ") }
        if n.contains("soc mtr") { return raw.replacingOccurrences(of: "SOC MTR Temp Sensor", with: "SoC ") }
        return raw
    }

    // MARK: SMC

    private func readFans() -> [FanInfo] {
        guard smc != 0 else { return [] }
        if fanCount == nil { fanCount = readSMC("FNum").map { Int($0) } ?? 0 }
        guard let count = fanCount, count > 0 else { return [] }
        return (0..<count).compactMap { i in
            guard let rpm = readSMC("F\(i)Ac") else { return nil }
            return FanInfo(id: i, rpm: max(0, rpm), min: readSMC("F\(i)Mn") ?? 0, max: readSMC("F\(i)Mx") ?? 0)
        }
    }

    func readSMC(_ key: String) -> Double? {
        guard smc != 0 else { return nil }
        var type: UInt32 = 0
        var size: UInt32 = 0
        var bytes = [UInt8](repeating: 0, count: 32)
        guard smc_read_key(smc, key, &type, &bytes, &size) == 0 else { return nil }
        return Self.decode(type: type, bytes: bytes, size: Int(size))
    }

    private static func decode(type: UInt32, bytes: [UInt8], size: Int) -> Double? {
        let fourCC = String(bytes: [24, 16, 8, 0].map { UInt8((type >> $0) & 0xff) }, encoding: .ascii) ?? ""
        switch fourCC {
        case "flt " where size >= 4:
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let v = Double(Float(bitPattern: bits))
            return v.isFinite ? v : nil
        case "fpe2" where size >= 2:
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case "sp78" where size >= 2:
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "ui8 ": return Double(bytes[0])
        case "ui16" where size >= 2: return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32" where size >= 4:
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        default: return nil
        }
    }
}
