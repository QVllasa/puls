import Darwin
import Foundation

enum Sysctl {
    static func int(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        switch size {
        case 4: return Int(Int32(truncatingIfNeeded: value))
        default: return Int(value)
        }
    }

    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static var bootTime: Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
    }
}

/// Feste Anzahl an Messwerten für Verlaufsgrafiken.
struct History: Equatable {
    private(set) var values: [Double] = []
    var capacity: Int = 60

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }

    var last: Double { values.last ?? 0 }
    var max: Double { values.max() ?? 0 }
}

struct MachineInfo {
    let computerName: String
    let chip: String
    let modelIdentifier: String
    let physicalMemory: UInt64
    let osVersion: String

    static let current: MachineInfo = {
        let chip = Sysctl.string("machdep.cpu.brand_string") ?? "Mac"
        let model = Sysctl.string("hw.model") ?? ""
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return MachineInfo(
            computerName: Host.current().localizedName ?? "Mac",
            chip: chip,
            modelIdentifier: model,
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            osVersion: "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
        )
    }()
}
