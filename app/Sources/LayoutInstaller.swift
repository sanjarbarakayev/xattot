import Foundation

/// Copies the layout bundle shipped inside the app into ~/Library/Keyboard Layouts,
/// so sharing the app alone is enough.
enum LayoutInstaller {
    enum Outcome {
        /// updated: an older copy was replaced; apps already open may keep typing with it.
        case upToDate, installed, updated, failed(Error)
    }

    private static let bundleName = "Xattot.bundle"
    private static let systemWide = URL(fileURLWithPath: "/Library/Keyboard Layouts").appendingPathComponent(bundleName)
    private static var userCopy: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keyboard Layouts/\(bundleName)")
    }

    static func installIfNeeded() -> Outcome {
        guard let embedded = Bundle.main.url(forResource: "Xattot", withExtension: "bundle") else {
            return .upToDate
        }
        let fm = FileManager.default
        // A copy installed for all users wins; a second one would duplicate the source.
        if fm.fileExists(atPath: systemWide.path) {
            return .upToDate
        }
        let destination = userCopy
        if BundleInstaller.action(embedded: embedded, destination: destination) == .none {
            return .upToDate
        }
        return BundleInstaller.install(embedded, to: destination)
    }

    /// Drops the input source caches and registers the installed bundle, for when macOS has not picked it up.
    static func refreshInputSources() {
        BundleInstaller.dropInputSourceCaches()
        let fm = FileManager.default
        if let installed = [systemWide, userCopy].first(where: { fm.fileExists(atPath: $0.path) }) {
            InputSources.register(installed)
        }
    }
}
