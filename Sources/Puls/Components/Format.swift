import Foundation

enum Fmt {
    /// Sprache der Oberfläche (folgt der vom System gewählten Lokalisierung der App).
    static let isGerman = Bundle.main.preferredLocalizations.first?.hasPrefix("de") ?? false

    private static func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic))
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))" + (isGerman ? "\u{202F}%" : "%")
    }

    /// Arbeitsspeicher (binär, wie in der Aktivitätsanzeige).
    static func memory(_ bytes: UInt64) -> String {
        let gib = Double(bytes) / 1_073_741_824
        if gib >= 1 { return "\(number(gib, digits: 1))\u{202F}GB" }
        let mib = Double(bytes) / 1_048_576
        return "\(number(mib, digits: 0))\u{202F}MB"
    }

    /// Speicherplatz (dezimal, wie im Finder).
    static func storage(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= 1e12 { return "\(number(value / 1e12, digits: 2))\u{202F}TB" }
        if value >= 1e9 { return "\(number(value / 1e9, digits: value >= 1e11 ? 0 : 1))\u{202F}GB" }
        if value >= 1e6 { return "\(number(value / 1e6, digits: 0))\u{202F}MB" }
        return "\(number(value / 1e3, digits: 0))\u{202F}KB"
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let v = max(0, bytesPerSecond)
        if v >= 1e9 { return "\(number(v / 1e9, digits: 1))\u{202F}GB/s" }
        if v >= 1e6 { return "\(number(v / 1e6, digits: v >= 1e8 ? 0 : 1))\u{202F}MB/s" }
        return "\(number(v / 1e3, digits: 0))\u{202F}KB/s"
    }

    /// Kurze Rate für die Menüleiste, z. B. „1,2M“ oder „340K“.
    static func compactRate(_ bytesPerSecond: Double) -> String {
        let v = max(0, bytesPerSecond)
        if v >= 1e9 { return "\(number(v / 1e9, digits: 1)) GB/s" }
        if v >= 1e6 { return "\(number(v / 1e6, digits: v >= 1e8 ? 0 : 1)) MB/s" }
        return "\(number(v / 1e3, digits: 0)) KB/s"
    }

    static func temperature(_ celsius: Double, fahrenheit: Bool) -> String {
        let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))\u{202F}°\(fahrenheit ? "F" : "C")"
    }

    static func watts(_ value: Double) -> String {
        "\(number(abs(value), digits: abs(value) >= 100 ? 0 : 1))\u{202F}W"
    }

    static func rpm(_ value: Double) -> String {
        String(localized: "\(number(value, digits: 0)) rpm")
    }

    static func minutes(_ total: Int) -> String {
        let h = total / 60, m = total % 60
        if h == 0 { return String(localized: "\(m) min") }
        return m == 0 ? String(localized: "\(h) h") : String(localized: "\(h) h \(m) min")
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let days = minutes / 1440, hours = (minutes % 1440) / 60, mins = minutes % 60
        if days > 0 { return String(localized: "\(days) d \(hours) h") }
        if hours > 0 { return String(localized: "\(hours) h \(mins) min") }
        return String(localized: "\(mins) min")
    }

    static func load(_ value: Double) -> String { number(value, digits: 2) }
}
