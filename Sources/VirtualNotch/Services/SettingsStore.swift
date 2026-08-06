import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "virtualNotch.settings.v1"
    private let layoutVersionKey = "virtualNotch.layoutVersion"
    private let currentLayoutVersion = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotchSettings {
        guard let data = defaults.data(forKey: key),
              var settings = try? JSONDecoder().decode(NotchSettings.self, from: data) else {
            defaults.set(currentLayoutVersion, forKey: layoutVersionKey)
            return .default
        }

        let storedLayoutVersion = defaults.integer(forKey: layoutVersionKey)
        if storedLayoutVersion < 6 {
            settings.compactWidth = NotchSettings.default.compactWidth
            settings.compactHeight = NotchSettings.default.compactHeight
            settings.expandedWidth = NotchSettings.default.expandedWidth
            settings.expandedHeight = NotchSettings.default.expandedHeight
        }
        if storedLayoutVersion < currentLayoutVersion {
            settings.compactContentLeadingPadding = 20
            settings.compactContentTrailingPadding = 20
        }
        settings.clampValues()
        save(settings)
        return settings
    }

    func save(_ settings: NotchSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        defaults.set(currentLayoutVersion, forKey: layoutVersionKey)
    }
}
