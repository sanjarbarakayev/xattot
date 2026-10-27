import Foundation

/// Copies the layout bundle shipped inside the app into ~/Library/Keyboard Layouts,
/// so sharing the app alone is enough.
enum LayoutInstaller {
    enum Outcome {
        /// updated: an older copy was replaced; apps already open may keep typing with it.
        case upToDate, installed, updated, failed(Error)
    }

    private static let bundleName = "Xattot.bundle"

    static func installIfNeeded() -> Outcome {
        guard let embedded = Bundle.main.url(forResource: "Xattot", withExtension: "bundle") else {
            return .upToDate
        }
        let fm = FileManager.default
        let systemWide = URL(fileURLWithPath: "/Library/Keyboard Layouts").appendingPathComponent(bundleName)
        // A copy installed for all users wins; a second one would duplicate the source.
        if fm.fileExists(atPath: systemWide.path) {
            return .upToDate
        }
        let folder = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Keyboard Layouts")
        let destination = folder.appendingPathComponent(bundleName)
        if version(of: destination) == version(of: embedded) {
            return .upToDate
        }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let replacing = fm.fileExists(atPath: destination.path)
            if replacing {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: embedded, to: destination)
            dropInputSourceCaches()
            return replacing ? .updated : .installed
        } catch {
            return .failed(error)
        }
    }

    // Each sandboxed app keeps its own input source table and reloads it on change, so one made before
    // this layout lacks it, and switching to it with Fn crashes the app (CFRelease(NULL) in TextInputUIMacHelper).
    // Without the files, macOS rebuilds the tables from the installed layouts.
    private static func dropInputSourceCaches() {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count) > 0 else { return }
        let fm = FileManager.default
        let cache = URL(fileURLWithPath: String(cString: buffer))
        let appFolders = (try? fm.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)) ?? []
        for folder in [cache] + appFolders {
            for name in ["com.apple.IntlDataCache.le", "com.apple.IntlDataCache.le.kbdx"] {
                try? fm.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    // Read the plist directly: Bundle(url:) caches and would miss an updated copy.
    private static func version(of bundle: URL) -> String? {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: plist)?["CFBundleVersion"] as? String
    }
}
