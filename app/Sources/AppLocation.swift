import AppKit

/// Moves the app into Applications when it is started straight from the DMG or from a
/// translocated download, where it would disappear on eject or run from a random path.
enum AppLocation {
    static var needsMove: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
    }

    /// True when a copy in Applications is being launched and this process should stop.
    static func offerMove() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Xattot'ni Applications'ga köçiraymi?"
        alert.informativeText = """
            Ilova hozir disk obrazidan (DMG) yoki yuklab olingan joyidan işlayapti \
            va uni yopsangiz yöqoladi. Applications'ga köçirib, öşa yerdan oçaman.
            """
        alert.addButton(withTitle: "Köçiriş")
        alert.addButton(withTitle: "Hozir emas")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        do {
            let target = try copyToApplications()
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: target, configuration: configuration) { _, _ in
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
            return true
        } catch {
            let failure = NSAlert()
            failure.messageText = "Köçirib bölmadi"
            failure.informativeText = "\(error.localizedDescription)\n\nIlovani Applications papkasiga özingiz sudrab qöying."
            failure.runModal()
            return false
        }
    }

    // /Applications needs an admin account; ~/Applications works for everyone.
    private static func copyToApplications() throws -> URL {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let folders = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
        var lastError: Error = CocoaError(.fileWriteNoPermission)
        for folder in folders {
            let target = folder.appendingPathComponent(source.lastPathComponent)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                if fm.fileExists(atPath: target.path) {
                    try fm.removeItem(at: target)
                }
                try fm.copyItem(at: source, to: target)
                Quarantine.clear(target)
                return target
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
