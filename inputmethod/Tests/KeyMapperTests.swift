import Foundation

private func facts(_ code: UInt16, _ chars: String? = nil, ignoring: String? = nil,
                   cmd: Bool = false, ctrl: Bool = false, opt: Bool = false, shift: Bool = false) -> KeyFacts {
    KeyFacts(keyCode: code, characters: chars, charactersIgnoringModifiers: ignoring ?? chars,
             command: cmd, control: ctrl, option: opt, shift: shift)
}

func runKeyMapperTests() {
    let named: [(UInt16, NamedKey, String)] = [
        (36, .returnKey, "Return"), (76, .enter, "Enter"), (48, .tab, "Tab"), (53, .escape, "Escape"),
        (123, .left, "Left"), (124, .right, "Right"), (125, .down, "Down"), (126, .up, "Up"),
        (51, .backspace, "Backspace"),
    ]
    for (code, key, name) in named {
        check(KeyMapper.key(facts(code)) == .named(key), "\(name) maps to its named key")
    }
    check(KeyMapper.key(facts(126, "\u{F700}")) == .named(.up), "an arrow wins over its private-use characters")

    check(KeyMapper.key(facts(0, "a", cmd: true)) == .shortcut, "Cmd+letter is a shortcut")
    check(KeyMapper.key(facts(0, "\u{1}", ctrl: true)) == .shortcut, "Ctrl+letter is a shortcut")
    check(KeyMapper.key(facts(51, cmd: true)) == .shortcut, "Cmd+Backspace is a shortcut")
    check(KeyMapper.key(facts(51, ctrl: true)) == .shortcut, "Ctrl+Backspace is a shortcut")
    check(KeyMapper.key(facts(51, opt: true)) == .shortcut, "Option+Backspace is a shortcut")
    check(KeyMapper.key(facts(123, cmd: true)) == .shortcut, "Cmd+Left is a shortcut")
    for code: UInt16 in [117, 115, 119, 116, 121] {
        check(KeyMapper.key(facts(code, "\u{F728}")) == .shortcut, "keyCode \(code) is a shortcut")
    }

    check(KeyMapper.key(facts(1, "s")) == .character("s", option: false), "plain s")
    check(KeyMapper.key(facts(1, "S", shift: true)) == .character("S", option: false), "Shift+s is S")
    check(KeyMapper.key(facts(18, "1")) == .character("1", option: false), "a digit")
    check(KeyMapper.key(facts(39, "'")) == .character("'", option: false), "an apostrophe")
    check(KeyMapper.key(facts(49, " ")) == .character(" ", option: false), "Space")

    check(KeyMapper.key(facts(1, "ß", ignoring: "s", opt: true)) == .character("s", option: true), "Option+s carries s")
    check(KeyMapper.key(facts(1, "Í", ignoring: "s", opt: true, shift: true)) == .character("S", option: true),
          "Shift+Option+s carries S")
    check(KeyMapper.key(facts(1, "Í", ignoring: "S", opt: true, shift: true)) == .character("S", option: true),
          "Shift+Option+S already upper")
    check(KeyMapper.key(facts(39, "æ", ignoring: "'", opt: true)) == .character("'", option: true), "Option+'")
    check(KeyMapper.key(facts(1, "ß", ignoring: "ß", opt: true, shift: true)) == .character("ß", option: true),
          "an upper-casing that would grow keeps the original")
    check(KeyMapper.key(KeyFacts(keyCode: 1, characters: "x", charactersIgnoringModifiers: nil,
                                 command: false, control: false, option: true, shift: false)) == nil,
          "Option without base characters is not ours")

    let fKeys: [UInt16] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
    for code in fKeys {
        check(KeyMapper.key(facts(code, "\u{F704}")) == nil, "F-key \(code) is not ours")
    }
    check(KeyMapper.key(facts(122, "\u{F704}", cmd: true)) == nil, "Cmd+F1 is not ours")
    check(KeyMapper.key(facts(0, nil)) == nil, "no characters is not ours")
    check(KeyMapper.key(facts(0, "")) == nil, "empty characters is not ours")
    check(KeyMapper.key(facts(0, "\u{1B}")) == nil, "a control character is not ours")
    check(KeyMapper.key(facts(0, "\u{F72C}")) == nil, "a private-use function character is not ours")
}
