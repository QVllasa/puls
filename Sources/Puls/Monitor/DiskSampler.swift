import Foundation
import IOKit

struct VolumeInfo: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let total: UInt64
    let available: UInt64
    let isInternal: Bool
    let isRemovable: Bool

    var used: UInt64 { total > available ? total - available : 0 }
    var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
}

struct DiskStats: Equatable {
    var read: Double = 0     // Bytes pro Sekunde
    var write: Double = 0
}

final class DiskSampler {
    private var previous: (read: UInt64, write: UInt64, time: TimeInterval)?

    func sampleThroughput() -> DiskStats {
        let (read, write) = Self.totalBytes()
        let now = ProcessInfo.processInfo.systemUptime
        var stats = DiskStats()
        if let previous, now > previous.time, read >= previous.read, write >= previous.write {
            let dt = now - previous.time
            stats.read = Double(read - previous.read) / dt
            stats.write = Double(write - previous.write) / dt
        }
        previous = (read, write, now)
        return stats
    }

    private static func totalBytes() -> (UInt64, UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                write += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (read, write)
    }

    static func volumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey,
            .volumeIsRemovableKey, .volumeIsBrowsableKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var result: [VolumeInfo] = []
        for url in urls {
            let path = url.path
            if path.hasPrefix("/System/Volumes") || path.hasPrefix("/private/") { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable ?? true,
                  let total = values.volumeTotalCapacity, total > 0 else { continue }
            let important = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) } ?? 0
            let available = important > 0 ? important : UInt64(max(0, values.volumeAvailableCapacity ?? 0))
            result.append(VolumeInfo(
                name: values.volumeName ?? url.lastPathComponent,
                path: path,
                total: UInt64(total),
                available: min(available, UInt64(total)),
                isInternal: values.volumeIsInternal ?? false,
                isRemovable: values.volumeIsRemovable ?? false
            ))
        }
        return result.sorted { ($0.path == "/" ? 0 : 1, $0.name) < ($1.path == "/" ? 0 : 1, $1.name) }
    }
}
