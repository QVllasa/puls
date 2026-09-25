import AppKit

if CommandLine.arguments.contains("--dump") {
    Dump.run()
    exit(0)
}
