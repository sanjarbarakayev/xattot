// Throwaway spike that tested the input method approach on real apps; see ../README.md.
import Cocoa
import InputMethodKit

let info = Bundle.main.infoDictionary!
let connection = info["InputMethodConnectionName"] as! String
let server = IMKServer(name: connection, bundleIdentifier: Bundle.main.bundleIdentifier!)
NSLog("XattotSpike: server up on %@", connection)
NSApplication.shared.run()
