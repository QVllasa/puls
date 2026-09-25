import AppKit

if CommandLine.arguments.contains("--dump") {
    Dump.run()
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
    let snapshot = MainActor.assumeIsolated { Snapshot(directory: CommandLine.arguments[index + 1]) }
    MainActor.assumeIsolated { snapshot.start() }
    app.run()
} else {
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    app.delegate = delegate
    app.run()
}
