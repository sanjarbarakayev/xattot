// Registers an installed layout bundle with the Text Input Sources service, so a freshly copied
// bundle shows every layout without a log out. Usage: swift register_layout.swift <bundle path>
import Carbon

guard CommandLine.arguments.count == 2 else {
    print("usage: swift register_layout.swift <bundle path>")
    exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let status = TISRegisterInputSource(url)
if status != noErr {
    print("TISRegisterInputSource failed: \(status)")
    exit(1)
}
