import Foundation
import IOKit
import IOKit.ps

struct BatteryStats: Equatable {
    var percent: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var isFullyCharged = false
    var minutesRemaining: Int?       // bis leer bzw. bis voll
    var cycleCount: Int?
    var health: Double?              // aktuelle Maximalkapazität in % der Designkapazität
    var temperature: Double?
    var power: Double?               // Watt, positiv = lädt, negativ = entlädt
    var adapterWatts: Int?
    var condition: String?

    var stateLabel: String {
        if isFullyCharged && isPluggedIn { return "Voll geladen" }
        if isCharging { return "Wird geladen" }
        if isPluggedIn { return "Am Netzteil" }
        return "Batteriebetrieb"
    }

    var symbolName: String {
        if isCharging { return "battery.100percent.bolt" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

enum BatterySampler {
    static func sample() -> BatteryStats? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        var stats: BatteryStats?
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            var s = BatteryStats()
            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
            s.percent = max > 0 ? Double(current) / Double(max) * 100 : 0
            s.isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            s.isPluggedIn = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            s.isFullyCharged = info[kIOPSIsChargedKey] as? Bool ?? false
            let minutes = s.isCharging ? info[kIOPSTimeToFullChargeKey] as? Int : info[kIOPSTimeToEmptyKey] as? Int
            if let minutes, minutes > 0, minutes < 24 * 60 { s.minutesRemaining = minutes }
            s.condition = info["BatteryHealth"] as? String
            stats = s
        }
        guard var stats else { return nil }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                stats.cycleCount = dict["CycleCount"] as? Int
                if let design = dict["DesignCapacity"] as? Int, design > 0,
                   let raw = (dict["AppleRawMaxCapacity"] as? Int) ?? (dict["NominalChargeCapacity"] as? Int) {
                    stats.health = min(100, Double(raw) / Double(design) * 100)
                }
                if let t = dict["Temperature"] as? Int { stats.temperature = Double(t) / 100 }
                if let mv = dict["Voltage"] as? Int {
                    let ma = (dict["InstantAmperage"] as? Int) ?? (dict["Amperage"] as? Int) ?? 0
                    let watts = Double(mv) * Double(ma) / 1_000_000
                    if abs(watts) >= 0.1 { stats.power = watts }
                }
                if let adapter = dict["AdapterDetails"] as? [String: Any], let w = adapter["Watts"] as? Int, w > 0 {
                    stats.adapterWatts = w
                }
            }
        }
        return stats
    }
}
