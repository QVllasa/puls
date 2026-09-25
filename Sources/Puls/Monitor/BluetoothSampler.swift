import Foundation
import IOKit

struct BluetoothDevice: Identifiable, Equatable {
    var id: String { address ?? name }
    var address: String? = nil
    let name: String
    let kind: String
    /// Beschriftete Akkustände, z. B. ["Links": 80, "Rechts": 75, "Case": 40] oder ["": 64].
    let levels: [(label: String, percent: Int)]

    var symbolName: String {
        let k = kind.lowercased(), n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if k.contains("headphone") || k.contains("headset") { return "headphones" }
        if k.contains("keyboard") || n.contains("keyboard") { return "keyboard" }
        if k.contains("mouse") || n.contains("mouse") { return "magicmouse" }
        if k.contains("trackpad") || n.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
        if k.contains("speaker") { return "hifispeaker" }
        if k.contains("gamepad") || k.contains("game") { return "gamecontroller" }
        return "dot.radiowaves.left.and.right"
    }

    static func == (a: BluetoothDevice, b: BluetoothDevice) -> Bool {
        a.name == b.name && a.kind == b.kind && a.levels.map(\.percent) == b.levels.map(\.percent)
    }
}

enum BluetoothSampler {
    /// Liest verbundene Geräte samt Akkustand über system_profiler (dauert ~1 s, daher selten aufrufen).
    static func sample() -> [BluetoothDevice] {
        guard let data = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"], timeout: 15),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["SPBluetoothDataType"] as? [[String: Any]] else { return [] }

        var devices: [BluetoothDevice] = []
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard let props = value as? [String: Any] else { continue }
                    var levels: [(String, Int)] = []
                    let map: [(String, String)] = [
                        ("device_batteryLevelMain", ""), ("device_batteryLevel", ""),
                        ("device_batteryLevelLeft", "L"), ("device_batteryLevelRight", "R"),
                        ("device_batteryLevelCase", "Case"),
                    ]
                    for (key, label) in map where !levels.contains(where: { $0.0 == label }) {
                        if let raw = props[key] as? String, let pct = Int(raw.filter(\.isNumber)) {
                            levels.append((label, pct))
                        }
                    }
                    devices.append(BluetoothDevice(address: props["device_address"] as? String,
                                                   name: name, kind: props["device_minorType"] as? String ?? "",
                                                   levels: levels.map { (label: $0.0, percent: $0.1) }))
                }
            }
        }
        // Magic Keyboard, Maus und Trackpad melden ihren Akkustand nur über IOKit.
        let hid = hidBatteryLevels()
        for (name, percent) in hid {
            if let index = devices.firstIndex(where: { $0.name == name }) {
                if devices[index].levels.isEmpty {
                    devices[index] = BluetoothDevice(address: devices[index].address, name: name,
                                                     kind: devices[index].kind, levels: [(label: "", percent: percent)])
                }
            } else {
                devices.append(BluetoothDevice(name: name, kind: "", levels: [(label: "", percent: percent)]))
            }
        }
        return devices.filter { !$0.levels.isEmpty }.sorted { $0.name < $1.name }
    }

    private static func hidBatteryLevels() -> [String: Int] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else {
            return [:]
        }
        defer { IOObjectRelease(iterator) }
        var result: [String: Int] = [:]
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let name = IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            let percent = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            if let name, let percent { result[name] = percent }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }
}

enum Shell {
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 5) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) { [weak process] in
            if let process, process.isRunning { process.terminate() }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
