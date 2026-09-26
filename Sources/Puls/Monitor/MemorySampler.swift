import Darwin
import Foundation

enum MemoryPressure: Int {
    case normal = 1, warning = 2, critical = 4

    var label: String {
        switch self {
        case .normal: String(localized: "Normal")
        case .warning: String(localized: "Elevated")
        case .critical: String(localized: "Critical")
        }
    }
}

struct MemoryStats: Equatable {
    var total: UInt64 = ProcessInfo.processInfo.physicalMemory
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var pressure: MemoryPressure = .normal
    /// Speicherdruck in Prozent (wie in der Aktivitätsanzeige).
    var pressurePercent: Double = 0

    var used: UInt64 { app + wired + compressed }
    var free: UInt64 { total > used ? total - used : 0 }
    var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
}

enum MemorySampler {
    static func sample() -> MemoryStats? {
        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let page = UInt64(vm_kernel_page_size)
        var stats = MemoryStats()
        let internalPages = UInt64(vm.internal_page_count)
        let purgeable = UInt64(vm.purgeable_count)
        stats.app = (internalPages > purgeable ? internalPages - purgeable : 0) * page
        stats.wired = UInt64(vm.wire_count) * page
        stats.compressed = UInt64(vm.compressor_page_count) * page
        stats.cached = (UInt64(vm.external_page_count) + purgeable) * page

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            stats.swapUsed = swap.xsu_used
            stats.swapTotal = swap.xsu_total
        }
        if let level = Sysctl.int("kern.memorystatus_vm_pressure_level") {
            stats.pressure = MemoryPressure(rawValue: level) ?? .normal
        }
        if let freeLevel = Sysctl.int("kern.memorystatus_level") {
            stats.pressurePercent = Double(max(0, min(100, 100 - freeLevel)))
        }
        return stats
    }
}
