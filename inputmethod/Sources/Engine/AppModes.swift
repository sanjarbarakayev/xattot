import Foundation

/// Persists the apps learned to need marked text; the input method supplies the storage.
protocol ModeStore {
    func learnedMarkedApps() -> Set<String>
    func saveLearnedMarkedApps(_ apps: Set<String>)
}

/// Which mode each client app gets: seeded Monaco editors plus apps learned at run time.
struct AppModes {
    static let seeded: Set<String> = [
        "com.microsoft.VSCode", "com.exafunction.windsurf", "com.todesktop.230313mzl4w4u92",
    ]

    /// Consecutive "no text" reports that mark an app for this session.
    private static let nilLimit = 3

    private let store: any ModeStore
    private var learned: Set<String>
    private var sessionMarked: Set<String> = []
    private var nilStreak: [String: Int] = [:]

    init(store: any ModeStore) {
        self.store = store
        learned = store.learnedMarkedApps()
    }

    func mode(for bundleID: String) -> Mode {
        AppModes.seeded.contains(bundleID) || learned.contains(bundleID) || sessionMarked.contains(bundleID)
            ? .marked : .eager
    }

    /// Reports what a replacement check found. Never call it right after a replacement:
    /// Chromium updates its text asynchronously, so an early read looks stale in any app.
    /// Stale text is learned and saved at once; "no text" must repeat and only lasts the session.
    /// `expected` and `staleView` come from `Engine.lastReplacement`.
    mutating func observe(bundleID: String, found: String?, expected: String, staleView: String) {
        guard mode(for: bundleID) == .eager else { return }
        guard let found else {
            let streak = (nilStreak[bundleID] ?? 0) + 1
            nilStreak[bundleID] = streak
            if streak >= AppModes.nilLimit { sessionMarked.insert(bundleID) }
            return
        }
        nilStreak[bundleID] = nil
        guard found == staleView, found != expected else { return }
        learned.insert(bundleID)
        store.saveLearnedMarkedApps(learned)
    }

    /// Undoes a wrong learning. Seeded apps stay marked.
    mutating func forget(_ bundleID: String) {
        sessionMarked.remove(bundleID)
        nilStreak[bundleID] = nil
        if learned.remove(bundleID) != nil { store.saveLearnedMarkedApps(learned) }
    }
}
