import Foundation

/// What the host knows about a key-down event, free of AppKit types.
struct KeyFacts {
    let keyCode: UInt16
    let characters: String?
    let charactersIgnoringModifiers: String?
    let command: Bool
    let control: Bool
    let option: Bool
    let shift: Bool
}

enum KeyMapper {
    private static let named: [UInt16: NamedKey] = [
        36: .returnKey, 76: .enter, 48: .tab, 53: .escape,
        123: .left, 124: .right, 125: .down, 126: .up, 51: .backspace,
    ]
    // Forward delete, Home, End, Page Up, Page Down.
    private static let navigation: Set<UInt16> = [117, 115, 119, 116, 121]
    // F1-F12 carry no text and never touch a word.
    private static let functionKeys: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    /// nil means the key is not ours: pass it on untouched, leave the word alone.
    static func key(_ facts: KeyFacts) -> Key? {
        if let key = named[facts.keyCode] {
            if facts.command || facts.control || (facts.option && key == .backspace) { return .shortcut }
            return .named(key)
        }
        if functionKeys.contains(facts.keyCode) { return nil }
        if navigation.contains(facts.keyCode) { return .shortcut }
        if facts.command || facts.control { return .shortcut }

        let source = facts.option ? baseCharacters(facts) : facts.characters
        guard let character = typed(source) else { return nil }
        return .character(character, option: facts.option)
    }

    private static func baseCharacters(_ facts: KeyFacts) -> String? {
        guard let base = facts.charactersIgnoringModifiers else { return nil }
        let upper = base.uppercased()
        return facts.shift && upper.count == base.count ? upper : base
    }

    // First character if it is text the user types; control and private-use (function key) scalars are not.
    private static func typed(_ text: String?) -> Character? {
        guard let character = text?.first, let scalar = character.unicodeScalars.first else { return nil }
        let value = scalar.value
        if value < 0x20 || value == 0x7F || (0xE000...0xF8FF).contains(value) { return nil }
        return character
    }
}
