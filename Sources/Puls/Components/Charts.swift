import SwiftUI

/// Weiche Verlaufslinie mit Farbverlauf-Fläche. Der neueste Wert steht rechts.
struct Sparkline: View {
    var values: [Double]
    var maxValue: Double? = nil
    var color: Color
    var capacity: Int = 60
    var lineWidth: CGFloat = 1.6
    var showsFill = true

    var body: some View {
        Canvas { context, size in
            let points = Self.points(values: values, maxValue: maxValue, capacity: capacity, size: size)
            guard points.count > 1 else { return }
            let line = Self.smoothPath(points)
            if showsFill {
                var area = line
                area.addLine(to: CGPoint(x: points.last!.x, y: size.height))
                area.addLine(to: CGPoint(x: points.first!.x, y: size.height))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.38), color.opacity(0.02)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            }
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                let dot = CGRect(x: last.x - 2.5, y: last.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }

    static func points(values: [Double], maxValue: Double?, capacity: Int, size: CGSize) -> [CGPoint] {
        guard !values.isEmpty, size.width > 0 else { return [] }
        let top = max(maxValue ?? (values.max() ?? 1) * 1.15, 0.0001)
        let step = size.width / CGFloat(max(capacity - 1, 1))
        let inset: CGFloat = 3
        let usable = size.height - inset
        let offset = CGFloat(capacity - values.count)
        return values.enumerated().map { i, v in
            let x = (offset + CGFloat(i)) * step
            let y = size.height - CGFloat(min(max(v, 0), top) / top) * usable
            return CGPoint(x: x, y: y)
        }
    }

    static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for i in 1..<points.count {
            let p0 = points[i - 1], p1 = points[i]
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            path.addQuadCurve(to: mid, control: p0)
            if i == points.count - 1 { path.addQuadCurve(to: p1, control: mid) }
        }
        return path
    }
}

/// Zwei Verläufe gespiegelt: oben eingehend, unten ausgehend (Netzwerk, Festplatte).
struct MirrorChart: View {
    var top: [Double]
    var bottom: [Double]
    var topColor: Color
    var bottomColor: Color

    var body: some View {
        let peak = max(top.max() ?? 0, bottom.max() ?? 0, 1024) * 1.1
        VStack(spacing: 1) {
            Sparkline(values: top, maxValue: peak, color: topColor)
            Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
            Sparkline(values: bottom, maxValue: peak, color: bottomColor)
                .scaleEffect(x: 1, y: -1)
        }
    }
}

struct RingGauge: View {
    var value: Double          // 0…100
    var color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(value, 100) / 100))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.55), color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(0.01, min(value, 100) / 100))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.smooth(duration: 0.6), value: value)
        .accessibilityElement()
        .accessibilityValue(Text(Fmt.percent(value)))
    }
}

struct MeterBar: View {
    var value: Double          // 0…100
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: value <= 0 ? 0 : max(height, geo.size.width * CGFloat(min(value, 100) / 100)))
                    .opacity(value <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.5), value: value)
        .accessibilityElement()
        .accessibilityValue(Text(Fmt.percent(value)))
    }
}

struct SegmentBar: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    var segments: [Segment]
    var total: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let width = total > 0 ? geo.size.width * CGFloat(segment.value / total) : 0
                    if width >= 1 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(segment.color.gradient)
                            .frame(width: max(0, width - 2))
                    }
                }
                Spacer(minLength: 0)
            }
            .background(Capsule().fill(.primary.opacity(0.08)))
            .clipShape(Capsule())
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.5), value: segments.map(\.value))
        .accessibilityHidden(true)
    }
}

/// Senkrechte Balken pro CPU-Kern.
struct CoreBars: View {
    var values: [Double]
    var color: Color
    var height: CGFloat = 34

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(values.indices, id: \.self) { i in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(.primary.opacity(0.07))
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Theme.level(values[i], base: color).gradient)
                        .frame(height: max(2, height * CGFloat(min(values[i], 100) / 100)))
                }
                .frame(maxWidth: 14)
                .frame(height: height)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.4), value: values)
        .accessibilityElement()
        .accessibilityLabel(Text("Load per core"))
        .accessibilityValue(Text(values.map { Fmt.percent($0) }.joined(separator: ", ")))
    }
}
