import AppKit
import Foundation
import Observation

/// Prüft (nur in der GitHub-Version) einmal täglich, ob es auf GitHub ein neueres Release gibt.
/// Die App-Store-Version wird von Apple aktualisiert und enthält diese Prüfung nicht.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    struct Release: Equatable {
        let version: String
        let url: URL
    }

    private(set) var available: Release?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let latestURL = URL(string: "https://api.github.com/repos/QVllasa/puls/releases/latest")!

    var isEnabled: Bool { !Flavor.isAppStore && Preferences.shared.checkForUpdates }

    func start() {
        guard !Flavor.isAppStore else { return }
        Task { await check() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    func check() async {
        guard isEnabled else { available = nil; return }
        var request = URLRequest(url: latestURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        available = Self.isNewer(version, than: Bundle.main.shortVersion) ? Release(version: version, url: page) : nil
    }

    /// Vergleicht Versionsnummern wie „1.10.0“ und „1.9.2“ numerisch.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func openDownload() {
        if let url = available?.url { NSWorkspace.shared.open(url) }
    }
}
