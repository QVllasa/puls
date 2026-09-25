import Foundation
import Observation
import ServiceManagement

enum MenuBarMetric: String, CaseIterable, Identifiable, Codable {
    case cpu, gpu, memory, network, disk, temperature, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "Grafik"
        case .memory: "Speicher"
        case .network: "Netzwerk"
        case .disk: "Festplatte"
        case .temperature: "Temperatur"
        case .battery: "Batterie"
        }
    }
}

@Observable
final class Preferences {
    static let shared = Preferences()

    @ObservationIgnored private let defaults = UserDefaults.standard

    var menuBarMetrics: [MenuBarMetric] {
        didSet { defaults.set(menuBarMetrics.map(\.rawValue), forKey: "menuBarMetrics") }
    }
    var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: "refreshInterval") }
    }
    var useFahrenheit: Bool {
        didSet { defaults.set(useFahrenheit, forKey: "useFahrenheit") }
    }
    var fetchPublicIP: Bool {
        didSet { defaults.set(fetchPublicIP, forKey: "fetchPublicIP") }
    }
    var coloredMenuBar: Bool {
        didSet { defaults.set(coloredMenuBar, forKey: "coloredMenuBar") }
    }
    var launchAtLogin: Bool {
        didSet {
            guard !syncingLoginItem, launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Puls: Anmeldeobjekt konnte nicht geändert werden: \(error)")
            }
            // Tatsächlichen Zustand übernehmen (z. B. wenn macOS die Freigabe verweigert hat).
            syncingLoginItem = true
            launchAtLogin = Self.loginItemIsOn
            syncingLoginItem = false
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    @ObservationIgnored private var syncingLoginItem = false

    private init() {
        defaults.register(defaults: [
            "menuBarMetrics": [MenuBarMetric.cpu, .memory, .network].map(\.rawValue),
            "refreshInterval": 2.0,
            "useFahrenheit": false,
            "fetchPublicIP": true,
            "coloredMenuBar": true,
        ])
        let raw = defaults.stringArray(forKey: "menuBarMetrics") ?? []
        menuBarMetrics = raw.compactMap(MenuBarMetric.init(rawValue:))
        refreshInterval = defaults.double(forKey: "refreshInterval")
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        fetchPublicIP = defaults.bool(forKey: "fetchPublicIP")
        coloredMenuBar = defaults.bool(forKey: "coloredMenuBar")
        launchAtLogin = Self.loginItemIsOn
    }

    /// Eingetragen gilt als „an“ – auch wenn macOS noch auf die Freigabe in den Systemeinstellungen wartet.
    static var loginItemIsOn: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    func isShown(_ metric: MenuBarMetric) -> Bool { menuBarMetrics.contains(metric) }

    func setShown(_ metric: MenuBarMetric, _ shown: Bool) {
        var set = Set(menuBarMetrics)
        if shown { set.insert(metric) } else { set.remove(metric) }
        // Reihenfolge immer wie in der Einstellungsliste
        menuBarMetrics = MenuBarMetric.allCases.filter(set.contains)
    }
}
