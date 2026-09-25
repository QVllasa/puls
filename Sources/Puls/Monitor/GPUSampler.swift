import Foundation
import IOKit

struct GPUStats: Equatable {
    var utilization: Double = 0
    var renderer: Double = 0
    var memoryInUse: UInt64 = 0
    var name: String = "GPU"
    var coreCount: Int?
}

enum GPUSampler {
    static func sample() -> GPUStats? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            guard let perf = property(service, "PerformanceStatistics") as? [String: Any] else {
                service = IOIteratorNext(iterator)
                continue
            }
            var stats = GPUStats()
            stats.utilization = number(perf["Device Utilization %"]) ?? 0
            stats.renderer = number(perf["Renderer Utilization %"]) ?? 0
            stats.memoryInUse = UInt64(number(perf["In use system memory"]) ?? 0)
            if let model = property(service, "model") as? String { stats.name = model }
            if let cores = property(service, "gpu-core-count") as? Int { stats.coreCount = cores }
            return stats
        }
        return nil
    }

    private static func property(_ service: io_object_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func number(_ any: Any?) -> Double? {
        (any as? NSNumber)?.doubleValue
    }
}
