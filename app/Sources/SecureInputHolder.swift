import AppKit
import IOKit

/// Guesses the app holding secure input and restarts it. Some apps, Chromium browsers among them,
/// keep secure input after the password field is gone, and only quitting them releases it.
enum SecureInputHolder {
    /// The console session's secure input PID is the app that was frontmost when secure input turned on,
    /// kept until every holder releases it: usually the holder, but not always. No API names the real one.
    static func pid() -> pid_t? {
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

    static func app() -> NSRunningApplication? {
        guard let pid = pid(), pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    static func holder(of app: NSRunningApplication?) -> SecureInputNotice.Holder? {
        guard let app else { return nil }
        let name =
            app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? "PID \(app.processIdentifier)"
        return .init(name: name, canRestart: app.activationPolicy == .regular && app.bundleURL != nil)
    }

    /// Asks the app to quit as Cmd+Q would and reopens it once it is gone. Returns false when macOS refused
    /// the request; an app that stays open (a save prompt the person cancels) is left alone.
    static func restart(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL else { return false }
        var observation: NSKeyValueObservation?
        let stop = {
            observation?.invalidate()
            observation = nil
        }
        observation = app.observe(\.isTerminated) { app, _ in
            guard app.isTerminated else { return }
            DispatchQueue.main.async {
                stop()
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        }
        guard app.terminate() else {
            stop()
            return false
        }
        // Without a deadline, a quit the person cancelled would reopen the app whenever it closes later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: stop)
        return true
    }
}
