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

    /// Reads the stored set before each write: every controller has its own `AppModes`.
    func learnMarkedApp(_ bundleID: String) {
        save(learnedMarkedApps().union([bundleID]))
    }

    func forgetMarkedApp(_ bundleID: String) {
        save(learnedMarkedApps().subtracting([bundleID]))
    }

    private func save(_ apps: Set<String>) {
        defaults.set(apps.sorted(), forKey: Self.key)
    }
}
