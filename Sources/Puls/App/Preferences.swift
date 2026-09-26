import Foundation
import Observation
import ServiceManagement

enum MenuBarMetric: String, CaseIterable, Identifiable, Codable {
    case cpu, gpu, memory, network, disk, temperature, battery

    var id: String { rawValue }

    /// In der Store-Version gibt es keine Chip-Temperaturen, daher auch keine Temperatur in der Menüleiste.
    static var available: [MenuBarMetric] {
        allCases.filter { !(Flavor.isAppStore && $0 == .temperature) }
    }

    var title: String {
        switch self {
        case .cpu: String(localized: "CPU")
        case .gpu: String(localized: "Graphics")
        case .memory: String(localized: "Memory")
        case .network: String(localized: "Network")
        case .disk: String(localized: "Disk")
        case .temperature: String(localized: "Temperature")
        case .battery: String(localized: "Battery")
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
    /// Store-Version: Der Nutzer hat die Autostart-Frage beantwortet (Regel 2.4.5: nur mit Zustimmung).
    var loginItemQuestionAnswered: Bool {
        didSet { defaults.set(loginItemQuestionAnswered, forKey: "loginItemQuestionAnswered") }
    }
    var checkForUpdates: Bool {
        didSet { defaults.set(checkForUpdates, forKey: "checkForUpdates") }
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
            "fetchPublicIP": !Flavor.isAppStore, // Store: Fremddienst nur nach eigener Wahl
            "coloredMenuBar": true,
            "checkForUpdates": true,
        ])
        let raw = defaults.stringArray(forKey: "menuBarMetrics") ?? []
        menuBarMetrics = raw.compactMap(MenuBarMetric.init(rawValue:)).filter(MenuBarMetric.available.contains)
        refreshInterval = defaults.double(forKey: "refreshInterval")
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        fetchPublicIP = defaults.bool(forKey: "fetchPublicIP")
        coloredMenuBar = defaults.bool(forKey: "coloredMenuBar")
        checkForUpdates = defaults.bool(forKey: "checkForUpdates")
        loginItemQuestionAnswered = defaults.bool(forKey: "loginItemQuestionAnswered")
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
        menuBarMetrics = MenuBarMetric.available.filter(set.contains)
    }
}
