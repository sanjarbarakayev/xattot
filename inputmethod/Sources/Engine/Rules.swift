import Foundation

/// Uzbek Latin alphabet rules (law OʻRQ-1184), mirroring the free layout's rules.py.
enum Rules {
    static let tutuq: Character = "ʼ"

    // Opener -> {next -> letter}. Capital openers accept a capital H as well.
    private static let digraphs: [Character: [Character: Character]] = [
        "c": ["h": "ç"],
        "C": ["h": "Ç", "H": "Ç"],
        "s": ["h": "ş"],
        "S": ["h": "Ş", "H": "Ş"],
        "o": ["'": "ö", "`": "ö"],
        "O": ["'": "Ö", "`": "Ö"],
        "g": ["'": "ğ", "`": "ğ"],
        "G": ["'": "Ğ", "`": "Ğ"],
    ]

    // Option+H types a plain h that never completes a digraph (s, Option+H gives "sh").
    // Shift+Option+' arrives as the quote character and also types tutuq.
    private static let optionLetters: [Character: String] = [
        "c": "ç", "C": "Ç",
        "s": "ş", "S": "Ş",
        "g": "ğ", "G": "Ğ",
        "o": "ö", "O": "Ö",
        "h": "h", "H": "H",
        "'": String(tutuq), "\"": String(tutuq),
    ]

    // The alphabet has no w, and c only in ch: a word holding either is foreign.
    static let foreignLetters: Set<Character> = ["w", "W"]
    static let foreignAfter: Set<Character> = ["c", "C"]

    static func digraph(_ opener: Character, _ next: Character) -> Character? {
        digraphs[opener]?[next]
    }

    static func isOpener(_ c: Character) -> Bool {
        digraphs[c] != nil
    }

    static func optionLetter(_ c: Character) -> String? {
        optionLetters[c]
    }
}
