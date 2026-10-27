import AppKit
import Carbon

struct Shortcut: Equatable {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags

    static let standard = Shortcut(keyCode: 31, modifiers: [.control, .option])

    private static let defaultsKey = "shortcut"
    private static let relevant: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Shortcut.relevant)
    }

    /// Needs Control, Option or Command, so it cannot swallow ordinary typing.
    var isUsable: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    var display: String {
        let symbols: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + KeyNames.label(for: keyCode)
    }

    static func load(from defaults: UserDefaults = .standard) -> Shortcut {
        guard let stored = defaults.dictionary(forKey: defaultsKey),
              let code = stored["keyCode"] as? Int,
              let mods = stored["modifiers"] as? Int
        else { return .standard }
        return Shortcut(keyCode: UInt32(code), modifiers: NSEvent.ModifierFlags(rawValue: UInt(mods)))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(["keyCode": Int(keyCode), "modifiers": Int(modifiers.rawValue)], forKey: Shortcut.defaultsKey)
    }
}

/// Key labels by ABC key code; the active layout may have dead keys, so it is not asked.
enum KeyNames {
    private static let labels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 10: "§",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    static func label(for keyCode: UInt32) -> String {
        labels[keyCode] ?? "#\(keyCode)"
    }
}
