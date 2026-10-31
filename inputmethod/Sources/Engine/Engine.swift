import Foundation

struct Engine {
    /// Changed only by `switchMode(_:)`, which flushes the old word first.
    private(set) var mode: Mode
    private let lexicon: any Lexicon
    private(set) var word = Word()
    /// Set whenever a `.replace` is emitted, for `AppModes.observe` after a failed check:
    /// a guard replacement fails after its word is already reset.
    private(set) var lastReplacement: (expected: String, staleView: String)?
    /// Created on first use in marked mode; it runs an eager engine of its own.
    private var composer: MarkedComposer?
    /// How to recover if the `.replace` in the last edits fails its check.
    private var undo: Undo?
    /// Characters typed since a backtick opened a code span, that backtick included; nil outside a span.
    private var codeSpan: Int?

    private enum Undo {
        /// Restore this word, untracked, and apply `fallback` in place of the replacement.
        case word(Word, fallback: [Edit])
        /// The guard's word is already over: nothing to undo, the next word is untouched.
        case finishedWord
    }

    init(lexicon: any Lexicon = EmptyLexicon(), mode: Mode = .eager) {
        self.lexicon = lexicon
        self.mode = mode
    }

    /// Ends the word, then changes the mode. Apply the returned edits before the next key.
    mutating func switchMode(_ newMode: Mode) -> [Edit] {
        let edits = endWord()
        if newMode != mode {
            mode = newMode
            reset()
        }
        return edits
    }

    /// Discards the current word and any marked state without emitting edits.
    mutating func reset() {
        composer = nil
        word = Word()
        undo = nil
        codeSpan = nil
    }

    /// Eager-mode test hook: pieces in the current word, one per client character once a word
    /// is reverted. Returns 0 in marked mode, where the word lives in the composer.
    var pieceCount: Int { word.pieces.count }

    /// True while a code span passes every key; the composer reads it from its inner engine.
    var inCodeSpan: Bool { codeSpan != nil }

    mutating func handle(_ key: Key) -> [Edit] {
        if mode == .marked { return marked { $0.handle(key) } }
        undo = nil
        if codeSpan != nil { return codeSpanKey(key) }
        switch key {
        case .character(let c, option: false) where c.isLetter:
            return letter(c)
        case .character(let c, option: false) where c == "'" || c == "`":
            return mark(c)
        case .character(let c, option: true):
            guard let typed = Rules.optionLetter(c) else { return endWord() + [.pass] }
            return optionInsert(typed)
        case .named(.backspace):
            backspace()
            return [.pass]
        case .character, .named, .shortcut:
            return endWord() + [.pass]
        }
    }

    mutating func endWord() -> [Edit] {
        if mode == .marked { return marked { $0.endWord() } }
        undo = nil
        codeSpan = nil
        defer { word = Word() }
        guard word.tracking else { return [] }
        let target = finalText(of: word)
        guard target != word.shown else { return [] }
        undo = .finishedWord
        return [replacement(of: word, with: target)]
    }

    /// A closing quote after o/g stays a plain mark (`'kino'`) whatever the English list says,
    /// and an English word gets its raw spelling back.
    private func finalText(of word: Word) -> String {
        let closed = word.closingQuoteSplit()
        guard closed.shown != closed.raw, isEnglishWord(closed), !isUzbekException(closed) else { return closed.shown }
        return closed.raw
    }

    /// Also tries the word without its closing quote: `'video'` typed as `'videö`.
    private func isEnglishWord(_ word: Word) -> Bool {
        lexicon.isEnglish(word.raw) || word.unquoted(word.raw).map(lexicon.isEnglish) == true
    }

    private func isUzbekException(_ word: Word) -> Bool {
        lexicon.isUzbekException(word.shown) || word.unquoted(word.shown).map(lexicon.isUzbekException) == true
    }

    private mutating func marked(_ body: (inout MarkedComposer) -> [Edit]) -> [Edit] {
        var current = composer ?? MarkedComposer(lexicon: lexicon)
        defer { composer = current }
        return body(&current)
    }

    /// Called when the `.replace` of the last edits failed its check.
    /// The result stands in for that `.replace`. Marked mode never emits one.
    mutating func replacementFailed() -> [Edit] {
        if mode == .marked { return [] }
        defer { undo = nil }
        switch undo {
        case .finishedWord?:
            return []
        case .word(let restored, let fallback)?:
            word = restored
            word.tracking = false
            return fallback
        case nil:
            word.tracking = false
            return []
        }
    }

    /// Replaces the whole word as shown, so a moved caret fails the check instead of editing other text.
    private mutating func replacement(of before: Word, with text: String) -> Edit {
        lastReplacement = (before.shown, before.staleView())
        return .replace(expected: before.shown, with: text)
    }

    /// Inside a code span every key is typed as is, across spaces and punctuation.
    private mutating func codeSpanKey(_ key: Key) -> [Edit] {
        switch key {
        case .character("`", option: false):
            codeSpan = nil
        case .character:
            codeSpan? += 1
        case .named(.backspace):
            // Deleting the opening backtick ends the span.
            if let typed = codeSpan, typed > 1 { codeSpan = typed - 1 } else { codeSpan = nil }
        case .named, .shortcut:
            codeSpan = nil
        }
        return [.pass]
    }

    /// The app deletes one character; its piece goes with it. A word emptied this way starts over.
    private mutating func backspace() {
        guard !word.pieces.isEmpty else {
            // The deleted character is the word's opening quote or lies before the word.
            word = Word()
            return
        }
        word.pieces.removeLast()
        if word.pieces.isEmpty {
            word = Word(openedBy: word.openedBy)
        } else if word.foreign, word.pieces.count <= word.foreignAt {
            word.foreign = false
        }
    }

    private mutating func letter(_ c: Character) -> [Edit] {
        if word.foreign || turnsForeign(by: c) { return foreignLetter(c) }
        if let merged = completeDigraph(with: c) { return merged }
        return append(Piece(raw: String(c), shown: String(c))) + [.pass]
    }

    /// Option keys type their character directly. The piece is the typed character itself
    /// (never an opener, never a foreign trigger), so nothing later joins or reverts it.
    private mutating func optionInsert(_ typed: String) -> [Edit] {
        let piece = Piece(raw: typed, shown: typed)
        if typed == String(Rules.tutuq) {
            word.pieces.append(piece)
            return [.insert(typed)]
        }
        return append(piece) + [.insert(typed)]
    }

    /// Adds the key's piece; a letter after a waiting apostrophe first turns it into tutuq.
    private mutating func append(_ piece: Piece) -> [Edit] {
        guard word.tracking, let i = word.pieces.indices.last, isApostrophe(word.pieces[i]) else {
            word.pieces.append(piece)
            return []
        }
        let before = word
        var restored = word
        restored.pieces.append(piece)
        undo = .word(restored, fallback: [])
        word.pieces[i].shown = String(Rules.tutuq)
        let edit = replacement(of: before, with: word.shown)
        word.pieces.append(piece)
        return [edit]
    }

    /// In a foreign word letters just pass; the letter that turns it foreign first
    /// puts back the raw keys of everything converted so far.
    private mutating func foreignLetter(_ c: Character) -> [Edit] {
        let piece = Piece(raw: String(c), shown: String(c))
        var edits: [Edit] = []
        if !word.foreign {
            word.foreign = true
            word.foreignAt = word.pieces.count
            if word.tracking, word.shown != word.raw {
                var restored = word
                restored.pieces.append(piece)
                undo = .word(restored, fallback: [])
                edits.append(replacement(of: word, with: word.raw))
                // One piece per character: Backspace removes one piece per deleted character.
                word.pieces = word.pieces.flatMap { $0.raw.map { Piece(raw: String($0), shown: String($0)) } }
                word.foreignAt = word.pieces.count
            }
        }
        word.pieces.append(piece)
        return edits + [.pass]
    }

    private func turnsForeign(by c: Character) -> Bool {
        if Rules.foreignLetters.contains(c) { return true }
        guard let last = word.pieces.last, last.raw.count == 1, let opener = last.raw.first else { return false }
        return Rules.foreignAfter.contains(opener) && Rules.digraph(opener, c) == nil
    }

    /// `'` or a backtick: finishes o'/g' as a letter, waits as a possible tutuq after a letter,
    /// opens a code span when a backtick starts a word, and is a plain word boundary anywhere else.
    private mutating func mark(_ c: Character) -> [Edit] {
        if word.foreign { return endWord() + [.pass] }
        if let merged = completeDigraph(with: c) { return merged }
        if c == "'", let last = word.pieces.last, last.raw.first?.isLetter == true,
            last.raw != String(Rules.tutuq)
        {
            word.pieces.append(Piece(raw: "'", shown: "'"))
            return [.pass]
        }
        let opens = word.pieces.isEmpty
        let edits = endWord()
        if opens, c == "`" {
            codeSpan = 1
        } else if opens {
            word.openedBy = c
        }
        return edits + [.pass]
    }

    private mutating func completeDigraph(with c: Character) -> [Edit]? {
        guard word.tracking, let last = word.pieces.last, last.raw.count == 1,
            let opener = last.raw.first, let joined = Rules.digraph(opener, c)
        else { return nil }
        let before = word
        var restored = word
        restored.pieces.append(Piece(raw: String(c), shown: String(c)))
        undo = .word(restored, fallback: [.pass])
        word.pieces[word.pieces.count - 1] = Piece(raw: last.raw + String(c), shown: String(joined))
        return [replacement(of: before, with: word.shown)]
    }

    private func isApostrophe(_ piece: Piece) -> Bool {
        piece.raw == "'" && piece.shown == "'"
    }
}
