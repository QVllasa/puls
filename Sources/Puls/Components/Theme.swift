import SwiftUI

enum Module: String, CaseIterable, Identifiable, Hashable {
    case cpu, gpu, memory, network, disk, sensors, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: String(localized: "CPU")
        case .gpu: String(localized: "Graphics")
        case .memory: String(localized: "Memory")
        case .network: String(localized: "Network")
        case .disk: String(localized: "Disk")
        case .sensors: Flavor.isAppStore ? String(localized: "Thermals") : String(localized: "Sensors")
        case .battery: String(localized: "Battery")
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
    /// Durchsichtiger Rand ums Glas: Liquid Glass zeichnet seinen Schatten außerhalb der runden Form.
    /// Füllte das Glas das Fenster ganz aus, schnitte der rechteckige Fensterrand diesen Schatten ab
    /// und hinter den runden Ecken bliebe ein eckiger Rahmen stehen. Gemessen reicht der Schatten
    /// oben 25, seitlich 33 und unten 41 Punkt weit.
    static let shadowInsets = NSEdgeInsets(top: 28, left: 36, bottom: 44, right: 36)

    /// Lage des Glases im Fenster (AppKit-Koordinaten, Ursprung unten links).
    static var glassFrameInWindow: CGRect {
        CGRect(x: shadowInsets.left, y: shadowInsets.bottom, width: width, height: height)
    }

    static var windowSize: CGSize {
        CGSize(width: width + shadowInsets.left + shadowInsets.right,
               height: height + shadowInsets.top + shadowInsets.bottom)
    }

    /// Fensterrahmen samt Schattenrand, das Glas mittig 6 Punkt unter dem Menüleisten-Symbol.
    static func windowFrame(below anchor: CGRect, in visible: CGRect) -> CGRect {
        var x = anchor.midX - width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - width - 8)
        let glassOrigin = CGPoint(x: x, y: anchor.minY - height - 6)
        return CGRect(origin: CGPoint(x: glassOrigin.x - shadowInsets.left, y: glassOrigin.y - shadowInsets.bottom),
                      size: windowSize)
    }
}
