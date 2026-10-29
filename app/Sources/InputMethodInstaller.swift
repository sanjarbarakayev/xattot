import AppKit

/// Copies the input method app shipped inside the app into ~/Library/Input Methods.
enum InputMethodInstaller {
    static let bundleID = "com.sanjarbarakayev.inputmethod.xattot"
    private static let bundleName = "XattotInputMethod.app"

    private static var destination: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/\(bundleName)")
    }

    static func installIfNeeded() -> LayoutInstaller.Outcome {
        guard let embedded = Bundle.main.url(forResource: "XattotInputMethod", withExtension: "app") else {
            return .upToDate
        }
        let destination = destination
        let action = BundleInstaller.action(embedded: embedded, destination: destination)
        if action == .none {
            return .upToDate
        }
        // A running copy keeps the old code and would hold the connection name the new one needs.
        if action == .replace {
            terminateRunning()
        }
        return BundleInstaller.install(embedded, to: destination)
    }

    private static func running() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }

    private static func terminateRunning() {
        running().forEach { $0.terminate() }
        waitUntilGone(timeout: 2)
        running().forEach { $0.forceTerminate() }
        waitUntilGone(timeout: 1)
    }

    private static func waitUntilGone(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while !running().isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
