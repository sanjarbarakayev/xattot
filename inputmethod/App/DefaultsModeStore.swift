import Foundation

/// Learned marked-text apps in the input method's own defaults.
struct DefaultsModeStore: ModeStore {
    private static let key = "learnedMarkedApps"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func learnedMarkedApps() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func saveLearnedMarkedApps(_ apps: Set<String>) {
        defaults.set(apps.sorted(), forKey: Self.key)
    }
}
