import Foundation

struct BluetoothDevice: Identifiable, Equatable {
    var id: String { name }
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
                    for (key, label) in map {
                        if let raw = props[key] as? String, let pct = Int(raw.filter(\.isNumber)) {
                            levels.append((label, pct))
                        }
                    }
                    devices.append(BluetoothDevice(name: name, kind: props["device_minorType"] as? String ?? "",
                                                   levels: levels.map { (label: $0.0, percent: $0.1) }))
                }
            }
        }
        return devices.sorted { $0.name < $1.name }
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
