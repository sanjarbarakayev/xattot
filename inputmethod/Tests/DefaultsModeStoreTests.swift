import Foundation

/// UserDefaults held in memory, so the tests write no preferences file.
private final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    override init?(suiteName: String?) { super.init(suiteName: suiteName) }

    override func object(forKey key: String) -> Any? { values[key] }
    override func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
}

func runDefaultsModeStoreTests() {
    guard let defaults = MemoryDefaults(suiteName: nil) else { return check(false, "store: in-memory defaults") }
    let store = DefaultsModeStore(defaults: defaults)
    // One AppModes per controller, all reading the input method's one defaults domain.
    var first = AppModes(store: store)
    var second = AppModes(store: DefaultsModeStore(defaults: defaults))
    first.observe(bundleID: "com.example.one", found: "pus", expected: "puş", staleView: "pus")
    second.observe(bundleID: "com.example.two", found: "pus", expected: "puş", staleView: "pus")
    check(store.learnedMarkedApps() == ["com.example.one", "com.example.two"],
          "store: a second controller keeps the app the first one learned")
    check(defaults.stringArray(forKey: "learnedMarkedApps") == ["com.example.one", "com.example.two"],
          "store: learned apps are stored sorted under learnedMarkedApps")

    second.forget("com.example.two")
    check(store.learnedMarkedApps() == ["com.example.one"], "store: forgetting removes only that app")
    first.forget("com.example.one")
    check(store.learnedMarkedApps().isEmpty, "store: a controller can forget an app it learned before another saved")
    check(AppModes(store: store).mode(for: "com.example.two") == .eager, "store: a forgotten app stays forgotten")
}
