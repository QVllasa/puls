import AppKit
import SwiftUI

/// Heller, halbtransparenter Untergrund für Karten auf dem Glas-Panel.
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18
    var highlighted = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(highlighted ? 0.11 : 0.06)
                                          : Color.white.opacity(highlighted ? 0.62 : 0.45))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.16 : 0.7),
                                                .white.opacity(scheme == .dark ? 0.03 : 0.2)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.8)
            }
    }
}

extension View {
    func card(cornerRadius: CGFloat = 18, highlighted: Bool = false) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

struct SectionCard<Content: View>: View {
    var title: String?
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.4)
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct InfoRow: View {
    var label: String
    var value: String
    var dot: Color? = nil
    var copyable = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            if let dot {
                Circle().fill(dot.gradient).frame(width: 8, height: 8)
            }
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(copied ? "Kopiert" : value)
                .monospacedDigit()
                .foregroundStyle(copied ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .truncationMode(.middle)
                .contentTransition(.numericText())
            if copyable {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.callout)
        .contentShape(Rectangle())
        .onTapGesture {
            guard copyable, value != "–" else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation(.snappy) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation(.snappy) { copied = false } }
        }
        .help(copyable ? "Klicken zum Kopieren" : "")
    }
}

/// Große Kennzahl mit kleiner Beschriftung.
struct BigValue: View {
    var value: String
    var caption: String
    var color: Color = .primary
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct LegendValue: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(color.gradient).frame(width: 7, height: 7)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProcessList: View {
    enum Mode { case cpu, memory }
    var rows: [ProcessRow]
    var mode: Mode

    var body: some View {
        VStack(spacing: 8) {
            if rows.isEmpty {
                HStack { ProgressView().controlSize(.small); Text("Wird geladen …").foregroundStyle(.secondary) }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    ProcessIcon(pid: row.id)
                    Text(row.name).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(mode == .cpu ? Fmt.percent(row.cpu) : Fmt.memory(row.memory))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .font(.callout)
            }
        }
        .animation(.snappy, value: rows.map(\.id))
    }
}

struct ProcessIcon: View {
    var pid: Int32

    var body: some View {
        Group {
            if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.primary.opacity(0.08)))
            }
        }
        .frame(width: 18, height: 18)
    }
}
