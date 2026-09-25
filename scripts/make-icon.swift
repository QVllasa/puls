// Erzeugt das App-Icon (Resources/AppIcon.icns) – vollflächig, macOS maskiert es selbst.
// Aufruf: swift scripts/make-icon.swift
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Hintergrund: tiefer Blau-Violett-Verlauf
    let colors = [NSColor(srgbRed: 0.20, green: 0.42, blue: 1.00, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.47, green: 0.26, blue: 0.96, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.78, green: 0.30, blue: 0.86, alpha: 1).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Weicher Glanz oben links (Glas-Anmutung)
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor.white.withAlphaComponent(0.45).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.28, y: s * 0.85), startRadius: 0,
                           endCenter: CGPoint(x: s * 0.28, y: s * 0.85), endRadius: s * 0.75, options: [])

    // Glas-Scheibe in der Mitte
    let pane = CGRect(x: s * 0.14, y: s * 0.24, width: s * 0.72, height: s * 0.52)
    let panePath = CGPath(roundedRect: pane, cornerWidth: s * 0.14, cornerHeight: s * 0.14, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.06, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(panePath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.20).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(panePath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(s * 0.008)
    ctx.strokePath()

    // Pulslinie
    let pts: [(CGFloat, CGFloat)] = [(0.22, 0.50), (0.38, 0.50), (0.44, 0.62), (0.51, 0.34), (0.58, 0.66), (0.63, 0.50), (0.78, 0.50)]
    let line = CGMutablePath()
    line.move(to: CGPoint(x: s * pts[0].0, y: s * pts[0].1))
    for p in pts.dropFirst() { line.addLine(to: CGPoint(x: s * p.0, y: s * p.1)) }
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.035, color: NSColor.white.withAlphaComponent(0.8).cgColor)
    ctx.addPath(line)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(s * 0.05)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    _ = rect
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: root.appendingPathComponent("AppIcon-1024.png"))
print("Iconset erzeugt:", iconset.path)
