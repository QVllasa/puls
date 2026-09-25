import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        VStack(spacing: 10) {
            SectionCard(title: "In der Menüleiste zeigen") {
                ForEach(MenuBarMetric.allCases) { metric in
                    HStack(spacing: 10) {
                        MenuBarMetricIcon(metric: metric)
                        Text(metric.title)
                        Spacer()
                        Toggle(metric.title, isOn: Binding(get: { prefs.isShown(metric) }, set: { prefs.setShown(metric, $0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .font(.callout)
                }
                Divider().opacity(0.5)
                SwitchRow(title: "Farbige Indikatoren", isOn: $prefs.coloredMenuBar)
                    .font(.callout)
            }
            SectionCard(title: "Allgemein") {
                HStack {
                    Text("Aktualisierung")
                    Spacer()
                    Picker("", selection: $prefs.refreshInterval) {
                        Text("1 s").tag(1.0)
                        Text("2 s").tag(2.0)
                        Text("5 s").tag(5.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                }
                HStack {
                    Text("Temperatur")
                    Spacer()
                    Picker("", selection: $prefs.useFahrenheit) {
                        Text("°C").tag(false)
                        Text("°F").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 100)
                }
                SwitchRow(title: "Öffentliche IP-Adresse abrufen", isOn: $prefs.fetchPublicIP)
                SwitchRow(title: "Beim Anmelden starten", isOn: $prefs.launchAtLogin)
            }
            .font(.callout)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Puls \(Bundle.main.shortVersion)").font(.callout.weight(.semibold))
                    Text("Rechtsklick auf das Menüleisten-Symbol öffnet das Menü")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
                    .buttonStyle(.glass)
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }
}

struct SwitchRow: View {
    var title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
