import Foundation

protocol Lexicon {
    func isEnglish(_ word: String) -> Bool
    func hasEnglishPrefix(_ prefix: String) -> Bool
    func isUzbekException(_ word: String) -> Bool
}

struct EmptyLexicon: Lexicon {
    func isEnglish(_ word: String) -> Bool { false }
    func hasEnglishPrefix(_ prefix: String) -> Bool { false }
    func isUzbekException(_ word: String) -> Bool { false }
}

/// Case-insensitive word lists: sorted English words (binary search) and a set of Uzbek exceptions.
struct WordListLexicon: Lexicon {
    private let english: [String]
    private let exceptions: Set<String>

    init(english: [String], uzbekExceptions: [String]) {
        self.english = Array(Set(english.map { $0.lowercased() })).sorted()
        self.exceptions = Set(uzbekExceptions.map { $0.lowercased() })
    }

    /// Reads `english-words.txt` and `uzbek-exceptions.txt`: one word per line, `#` lines are comments.
    static func load(from directory: URL) throws -> WordListLexicon {
        WordListLexicon(
            english: try words(in: directory.appendingPathComponent("english-words.txt")),
            uzbekExceptions: try words(in: directory.appendingPathComponent("uzbek-exceptions.txt")))
    }

    func isEnglish(_ word: String) -> Bool {
        let key = word.lowercased()
        let i = lowerBound(key)
        return i < english.count && english[i] == key
    }

    func hasEnglishPrefix(_ prefix: String) -> Bool {
        let key = prefix.lowercased()
        let i = lowerBound(key)
        return i < english.count && english[i].hasPrefix(key)
    }

    func isUzbekException(_ word: String) -> Bool {
        exceptions.contains(word.lowercased())
    }

    /// Index of the first English word that is not less than `key`.
    private func lowerBound(_ key: String) -> Int {
        var low = 0, high = english.count
        while low < high {
            let mid = (low + high) / 2
            if english[mid] < key { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private static func words(in file: URL) throws -> [String] {
        try String(contentsOf: file, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
