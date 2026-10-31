import AppKit
import IOKit

/// The app holding secure input, read as the menu bar app's `SecureInputHolder.pid()` reads it.
/// About 15 µs per read, and the controller reads it only while secure input is on.
enum SecureInputHolder {
    static func bundleID() -> String? {
        guard let pid = pid() else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    /// The console session's secure input PID: the app that was frontmost when secure input turned on.
    private static func pid() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard
            let users = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let session = users.first {
            ($0["kCGSSessionUserIDKey"] as? Int) == Int(getuid()) && ($0["kCGSSessionOnConsoleKey"] as? Bool) == true
        }
        return (session?["kCGSSessionSecureInputPID"] as? Int).map { pid_t($0) }
    }
}
