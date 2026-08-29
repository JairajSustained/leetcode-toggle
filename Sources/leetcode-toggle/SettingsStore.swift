import Foundation
import ServiceManagement

/// App preferences, persisted in UserDefaults.
/// (main-thread only in practice: SwiftUI + the app delegate)
final class SettingsStore: ObservableObject {

    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: Keys.username) }
    }
    @Published var refreshMinutes: Int {
        didSet { UserDefaults.standard.set(refreshMinutes, forKey: Keys.refreshMinutes) }
    }

    @Published var lastLaunchAtLoginError: String?

    private enum Keys {
        static let username = "username"
        static let refreshMinutes = "refreshMinutes"
    }

    init(defaults: UserDefaults = .standard) {
        username = defaults.string(forKey: Keys.username) ?? ""
        refreshMinutes = (defaults.object(forKey: Keys.refreshMinutes) as? Int) ?? 5
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                lastLaunchAtLoginError = nil
            } catch {
                lastLaunchAtLoginError = error.localizedDescription
            }
        }
    }

    var hasUsername: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty }

    var trimmedUsername: String { username.trimmingCharacters(in: .whitespaces) }

    var refreshInterval: TimeInterval { TimeInterval(refreshMinutes * 60) }
}
