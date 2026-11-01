import Cocoa
import InputMethodKit

guard let connection = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
    let bundleID = Bundle.main.bundleIdentifier,
    let server = IMKServer(name: connection, bundleIdentifier: bundleID)
else {
    NSLog("Xattot: no IMK server, Info.plist lacks a connection name or bundle ID")
    exit(1)
}
withExtendedLifetime(server) {
    NSApplication.shared.run()
}
