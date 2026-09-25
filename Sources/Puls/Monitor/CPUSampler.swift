import Darwin
import Foundation

struct CoreGroup: Identifiable, Equatable {
    let id: Int
    let name: String
    let range: Range<Int>
}

struct CPUStats: Equatable {
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 100
    var cores: [Double] = []
    var load: [Double] = [0, 0, 0]
}

final class CPUSampler {
    private struct Ticks { var user: UInt32; var system: UInt32; var idle: UInt32; var nice: UInt32 }
    private var previous: [Ticks] = []

    /// Kerngruppen (z. B. Effizienz- und Leistungskerne). Auf Apple Silicon kommen
    /// die sparsameren Kerne bei den niedrigen Indizes zuerst.
    let groups: [CoreGroup] = {
        let levels = Sysctl.int("hw.nperflevels") ?? 1
        var result: [CoreGroup] = []
        var start = 0
        for level in stride(from: levels - 1, through: 0, by: -1) {
            let count = Sysctl.int("hw.perflevel\(level).logicalcpu") ?? 0
            guard count > 0 else { continue }
            let raw = Sysctl.string("hw.perflevel\(level).name") ?? ""
            result.append(CoreGroup(id: level, name: CPUSampler.localizedGroupName(raw, level: level),
                                    range: start..<(start + count)))
            start += count
        }
        if result.isEmpty {
            let n = ProcessInfo.processInfo.processorCount
            result = [CoreGroup(id: 0, name: "Kerne", range: 0..<n)]
        }
        return result
    }()

    private static func localizedGroupName(_ raw: String, level: Int) -> String {
        switch raw.lowercased() {
        case "efficiency": return "Effizienzkerne"
        case "performance": return "Leistungskerne"
        case "super": return "Super-Kerne"
        default:
            if raw.isEmpty { return level == 0 ? "Leistungskerne" : "Effizienzkerne" }
            return raw.capitalized + "-Kerne"
        }
    }

    func sample() -> CPUStats? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        var current: [Ticks] = []
        current.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let base = Int(CPU_STATE_MAX) * i
            current.append(Ticks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            ))
        }
        guard previous.count == current.count else {
            previous = current
            return nil
        }

        var stats = CPUStats()
        var sumUser = 0.0, sumSystem = 0.0, sumIdle = 0.0
        for (now, before) in zip(current, previous) {
            let user = Double(now.user &- before.user) + Double(now.nice &- before.nice)
            let system = Double(now.system &- before.system)
            let idle = Double(now.idle &- before.idle)
            let total = user + system + idle
            stats.cores.append(total > 0 ? (user + system) / total * 100 : 0)
            sumUser += user; sumSystem += system; sumIdle += idle
        }
        let all = sumUser + sumSystem + sumIdle
        // Zu kurzes Messfenster (z. B. direkt nach dem Start) liefert nur grobe 0/50/100-%-Werte:
        // alten Bezugspunkt behalten und später erneut messen.
        guard all >= Double(current.count) * 10 else { return nil }
        previous = current
        if all > 0 {
            stats.user = sumUser / all * 100
            stats.system = sumSystem / all * 100
            stats.idle = sumIdle / all * 100
            stats.total = stats.user + stats.system
        }
        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 { stats.load = loads }
        return stats
    }
}
