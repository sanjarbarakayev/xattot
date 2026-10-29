import Foundation

/// Copy-by-version, cache drop and registration shared by the layout and input method installers.
enum BundleInstaller {
    enum Action: Equatable { case none, install, replace }

    /// Versions are content hashes, so any difference means the embedded copy is the one to have.
    static func action(installed: String?, embedded: String?) -> Action {
        guard let embedded else { return .none }
        guard let installed else { return .install }
        return installed == embedded ? .none : .replace
    }

    static func action(embedded: URL, destination: URL) -> Action {
        action(installed: version(of: destination), embedded: version(of: embedded))
    }

    /// Copies the bundle over any existing one, drops the input source caches and registers it.
    static func install(_ embedded: URL, to destination: URL) -> LayoutInstaller.Outcome {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let replacing = fm.fileExists(atPath: destination.path)
            if replacing {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: embedded, to: destination)
            dropInputSourceCaches()
            InputSources.register(destination)
            return replacing ? .updated : .installed
        } catch {
            return .failed(error)
        }
    }

    // Each sandboxed app keeps its own input source table and reloads it on change, so one made before
    // this layout lacks it, and switching to it with Fn crashes the app (CFRelease(NULL) in TextInputUIMacHelper).
    // Without the files, macOS rebuilds the tables from the installed layouts.
    static func dropInputSourceCaches() {
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
    static func version(of bundle: URL) -> String? {
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: plist)?["CFBundleVersion"] as? String
    }
}
