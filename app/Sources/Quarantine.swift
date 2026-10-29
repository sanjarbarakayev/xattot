import Foundation

enum Quarantine {
    /// Removes `com.apple.quarantine` from the bundle and everything inside it, never following links out.
    static func clear(_ bundle: URL) {
        let paths = [bundle.path] + (FileManager.default.enumerator(atPath: bundle.path)?
            .compactMap { ($0 as? String).map { bundle.appendingPathComponent($0).path } } ?? [])
        for path in paths {
            removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }
}
