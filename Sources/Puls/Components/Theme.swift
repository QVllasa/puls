import SwiftUI

enum Module: String, CaseIterable, Identifiable, Hashable {
    case cpu, gpu, memory, network, disk, sensors, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "Grafik"
        case .memory: "Speicher"
        case .network: "Netzwerk"
        case .disk: "Festplatte"
        case .sensors: Flavor.isAppStore ? "Thermik" : "Sensoren"
        case .battery: "Batterie"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "square.stack.3d.up.fill"
        case .memory: "memorychip"
        case .network: "arrow.up.arrow.down"
        case .disk: "internaldrive"
        case .sensors: "thermometer.medium"
        case .battery: "battery.75percent"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: .blue
        case .gpu: .purple
        case .memory: .mint
        case .network: .cyan
        case .disk: .indigo
        case .sensors: .orange
        case .battery: .green
        }
    }
}

enum Theme {
    static let download = Color.cyan
    static let upload = Color.orange
    static let read = Color.indigo
    static let write = Color.pink

    /// Ampelfarbe für Auslastungen in Prozent.
    static func level(_ percent: Double, base: Color) -> Color {
        switch percent {
        case ..<75: base
        case ..<90: .yellow
        default: .red
        }
    }

    static func temperature(_ celsius: Double) -> Color {
        switch celsius {
        case ..<55: .green
        case ..<75: .yellow
        case ..<90: .orange
        default: .red
        }
    }

    static func battery(_ percent: Double, charging: Bool) -> Color {
        if charging { return .green }
        switch percent {
        case ..<15: return .red
        case ..<30: return .orange
        default: return .green
        }
    }
}

enum PanelMetrics {
    static let width: CGFloat = 384
    static let height: CGFloat = 588
    static let cornerRadius: CGFloat = 30
}
