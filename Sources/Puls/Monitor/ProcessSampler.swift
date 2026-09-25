import AppKit
import Foundation

struct ProcessRow: Identifiable, Equatable {
    let id: Int32
    let name: String
    let cpu: Double
    let memory: UInt64
}

enum ProcessSampler {
    /// Liefert die Top-Prozesse nach CPU und Speicher. `ps` sieht als einziges Werkzeug
    /// ohne Root-Rechte auch Systemprozesse.
    static func sample(limit: Int = 5) -> (cpu: [ProcessRow], memory: [ProcessRow]) {
        guard let data = Shell.run("/bin/ps", ["-Aceo", "pid=,pcpu=,rss=,comm="]),
              let text = String(data: data, encoding: .utf8) else { return ([], []) }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var rows: [ProcessRow] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4, let pid = Int32(parts[0]), pid != ownPID,
                  let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")),
                  let rss = UInt64(parts[2]) else { continue }
            rows.append(ProcessRow(id: pid, name: displayName(pid: pid, fallback: String(parts[3])), cpu: cpu, memory: rss * 1024))
        }
        let byCPU = rows.sorted { $0.cpu > $1.cpu }.prefix(limit)
        let byMemory = rows.sorted { $0.memory > $1.memory }.prefix(limit)
        return (Array(byCPU), Array(byMemory))
    }

    private static func displayName(pid: Int32, fallback: String) -> String {
        NSRunningApplication(processIdentifier: pid)?.localizedName ?? fallback
    }
}
