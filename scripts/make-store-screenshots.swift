// Erzeugt die Mac-App-Store-Screenshots (2880 × 1800) aus den Panel-Aufnahmen.
// Aufruf: swift scripts/make-store-screenshots.swift <aufnahmen-ordner> <ziel-ordner>
// Der Aufnahmen-Ordner enthält dark/ und light/ aus `Puls --snapshot`.
import AppKit
import SwiftUI

let args = CommandLine.arguments
let source = URL(fileURLWithPath: args[1])
let target = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

func image(_ path: String) -> NSImage {
    guard let img = NSImage(contentsOf: source.appendingPathComponent(path)) else { fatalError("fehlt: \(path)") }
    return img
}

struct Slide: View {
    var title: String
    var subtitle: String
    var panels: [NSImage]
    var light = false
    var menubar: NSImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: light ? [Color(white: 0.96), Color(white: 0.86)]
                                         : [Color(red: 0.09, green: 0.095, blue: 0.12), Color(red: 0.035, green: 0.04, blue: 0.055)],
                           startPoint: .top, endPoint: .bottom)
            // sehr dezenter Schimmer in der Markenfarbe hinter dem Panel
            Circle()
                .fill(Color(red: 0.36, green: 0.36, blue: 0.94).opacity(light ? 0.10 : 0.16))
                .frame(width: 1500, height: 1500)
                .blur(radius: 260)
                .offset(x: 620, y: 120)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 90) {
                    VStack(alignment: .leading, spacing: 34) {
                        HStack(spacing: 22) {
                            Image(nsImage: NSImage(contentsOfFile: "Resources/AppIcon-1024.png")!)
                                .resizable().frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            Text("Puls").font(.system(size: 56, weight: .semibold, design: .rounded))
                                .foregroundStyle(light ? Color.black.opacity(0.75) : Color.white.opacity(0.85))
                        }
                        Text(title)
                            .font(.system(size: 124, weight: .bold, design: .default))
                            .kerning(-2)
                            .foregroundStyle(light ? Color.black : Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(.system(size: 50, weight: .regular))
                            .foregroundStyle(light ? Color.black.opacity(0.55) : Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 1180, alignment: .leading)

                    VStack(spacing: 44) {
                        if let menubar {
                            // Menüleisten-Anzeige vergrößert in einer Glas-Pille
                            Image(nsImage: menubar).resizable().interpolation(.high)
                                .aspectRatio(contentMode: .fit).frame(height: 104)
                                .padding(.horizontal, 26).padding(.vertical, 14)
                                .background(Capsule().fill(light ? Color.white.opacity(0.8) : Color(white: 0.14)))
                                .overlay(Capsule().strokeBorder(light ? Color.black.opacity(0.06) : Color.white.opacity(0.12), lineWidth: 2))
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(light ? 0.12 : 0.45), radius: 40, y: 18)
                        }
                        HStack(spacing: 50) {
                            ForEach(panels.indices, id: \.self) { i in
                                Image(nsImage: panels[i]).resizable().interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: menubar != nil ? (panels.count > 1 ? 1180 : 1300) : (panels.count > 1 ? 1280 : 1480))
                                    .shadow(color: .black.opacity(light ? 0.18 : 0.5), radius: 60, y: 30)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 150)
            }
        }
        .frame(width: 2880, height: 1800)
    }
}

let slides: [(String, Slide)] = [
    ("01-uebersicht", Slide(title: "Dein Mac auf einen Blick.",
                            subtitle: "CPU, Grafik, Speicher, Netzwerk, Festplatte und Akku – live in der Menüleiste.",
                            panels: [image("dark/overview.png")], menubar: image("dark/menubar-dark.png"))),
    ("02-cpu", Slide(title: "Jeder Kern. Jede Sekunde.",
                     subtitle: "Gesamtauslastung, alle Kerne nach Typ und die Systemlast – mit Verlauf.",
                     panels: [image("dark/cpu.png")])),
    ("03-speicher", Slide(title: "Speicher verstehen.",
                          subtitle: "App-Speicher, Speicherdruck und Auslagerung übersichtlich erklärt.",
                          panels: [image("dark/memory.png")])),
    ("04-netzwerk", Slide(title: "Netzwerk live.",
                          subtitle: "Download und Upload in Echtzeit, Spitzenwerte und übertragene Datenmenge.",
                          panels: [image("dark/network.png")])),
    ("05-batterie", Slide(title: "Akku und Energie im Griff.",
                          subtitle: "Zustand, Ladezyklen, Verbrauch und thermischer Zustand deines Mac.",
                          panels: [image("dark/battery.png"), image("dark/sensors.png")])),
    ("06-hell", Slide(title: "Deine Menüleiste, deine Wahl.",
                      subtitle: "Wähle die Werte für die Menüleiste – mit farbigen Ampel-Indikatoren. In Hell und Dunkel.",
                      panels: [image("light/overview.png"), image("light/network.png")], light: true,
                      menubar: image("light/menubar-light.png"))),
]

MainActor.assumeIsolated {
    for (name, slide) in slides {
        let renderer = ImageRenderer(content: slide)
        renderer.scale = 1
        guard let cg = renderer.cgImage else { fatalError("Rendern fehlgeschlagen: \(name)") }
        // App Store verlangt Bilder ohne Alphakanal
        let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        let data = rep.representation(using: .png, properties: [:])!
        let url = target.appendingPathComponent("\(name).png")
        try! data.write(to: url)
        print("✓", url.lastPathComponent, cg.width, "×", cg.height)
    }
}
