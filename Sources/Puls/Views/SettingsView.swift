import SwiftUI

struct SettingsView: View {
    @Environment(Preferences.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        VStack(spacing: 10) {
            SectionCard(title: "Show in menu bar") {
                ForEach(MenuBarMetric.available) { metric in
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
                SwitchRow(title: "Colored indicators", isOn: $prefs.coloredMenuBar)
                    .font(.callout)
            }
            SectionCard(title: "General") {
                HStack {
                    Text("Update interval")
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
                    Text("Temperature")
                    Spacer()
                    Picker("", selection: $prefs.useFahrenheit) {
                        Text("°C").tag(false)
                        Text("°F").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 100)
                }
                SwitchRow(title: "Show public IP address", isOn: $prefs.fetchPublicIP)
                SwitchRow(title: "Open at login", isOn: $prefs.launchAtLogin)
                if !Flavor.isAppStore {
                    SwitchRow(title: "Check for updates", isOn: $prefs.checkForUpdates)
                        .onChange(of: prefs.checkForUpdates) { Task { await UpdateChecker.shared.check() } }
                }
            }
            .font(.callout)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Puls \(Bundle.main.shortVersion)").font(.callout.weight(.semibold))
                    Text("Right-click the menu bar item to open the menu")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
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
            Text(LocalizedStringKey(title))
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
