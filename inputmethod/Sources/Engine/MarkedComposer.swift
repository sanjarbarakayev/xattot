import Foundation

/// Marked-text mode for clients that keep reporting pre-replacement text (Monaco editors).
/// An eager engine runs against a private copy of the current word; what it may still change
/// stays marked, everything else is committed with a plain insert, so no `.replace` reaches the client.
struct MarkedComposer {
    private let lexicon: any Lexicon
    private var box: InnerEngine
    /// Text of this word the client already holds: passed keys and committed text. Never edited.
    private var committed = ""
    /// Text of this word the client shows as marked.
    private var tail = ""

    init(lexicon: any Lexicon) {
        self.lexicon = lexicon
        box = .engine(Engine(lexicon: lexicon, mode: .eager))
    }

    mutating func handle(_ key: Key) -> [Edit] {
        // A code span passes every key; the inner engine tracks where it ends.
        if inner.inCodeSpan {
            committed = ""
            return inner.handle(key)
        }
        switch key {
        case .named(.backspace):
            return backspace()
        case .character(let c, option: false) where c.isLetter || c == "'" || c == "`":
            return compose(key, typed: c)
        case .character(let c, option: true) where Rules.optionLetter(c) != nil:
            return compose(key, typed: nil)
        case .character, .named, .shortcut:
            return endWord() + [.pass]
        }
    }

    /// Lets the English guard decide the tail, then commits all of it.
    mutating func endWord() -> [Edit] {
        apply(inner.endWord(), typed: nil)
        defer {
            committed = ""
            tail = ""
        }
        return tail.isEmpty ? [] : [.commit(tail)]
    }

    /// `typed` is the key's character when the app could type it itself (no Option).
    private mutating func compose(_ key: Key, typed: Character?) -> [Edit] {
        let wasMarked = !tail.isEmpty
        apply(inner.handle(key), typed: typed)
        let keep = undecidedLength()
        let settled = String(tail.dropLast(keep))
        tail = String(tail.suffix(keep))
        committed += settled
        if !wasMarked, tail.isEmpty, let typed, settled == String(typed) { return [.pass] }
        if settled.isEmpty { return [.setMarked(tail)] }
        return [.commit(settled)] + (tail.isEmpty ? [] : [.setMarked(tail)])
    }

    private mutating func backspace() -> [Edit] {
        // One piece per client character, so the inner engine's own Backspace keeps it in step.
        _ = inner.handle(.named(.backspace))
        if tail.isEmpty {
            if !committed.isEmpty { committed.removeLast() }
            return [.pass]
        }
        tail.removeLast()
        return [.setMarked(tail)]
    }

    /// Plays the inner engine's edits on the buffer. A replacement that reaches into
    /// the committed text fails, and the engine's own failure path takes over.
    private mutating func apply(_ edits: [Edit], typed: Character?) {
        for edit in edits {
            switch edit {
            case .pass:
                if let typed { tail.append(typed) }
            case .insert(let s), .commit(let s):
                tail += s
            case .setMarked:
                break
            case .replace(let expected, let with):
                if !replaceInTail(expected: expected, with: with) {
                    apply(inner.replacementFailed(), typed: typed)
                }
            }
        }
    }

    /// The guard replaces the whole word (`puş` -> `push`); only the part that differs must be in the tail.
    private mutating func replaceInTail(expected: String, with: String) -> Bool {
        guard (committed + tail).hasSuffix(expected) else { return false }
        let shared = zip(expected, with).prefix { $0 == $1 }.count
        let changed = expected.count - shared
        guard changed <= tail.count else { return false }
        tail = String(tail.dropLast(changed)) + String(with.dropFirst(shared))
        return true
    }

    /// Characters at the end of the tail that a later key may still change.
    private func undecidedLength() -> Int {
        let word = inner.word
        guard word.tracking, let last = word.pieces.last else { return 0 }
        var length = 0
        var converted = false
        for piece in word.pieces.reversed() {
            guard length + piece.shown.count <= tail.count else { break }
            length += piece.shown.count
            converted = converted || piece.raw != piece.shown
        }
        if converted, isEnglishPrefix(word) { return length }
        if isPending(last, in: word) || word.endsWithQuoteDigraph { return min(last.shown.count, tail.count) }
        return 0
    }

    private func isEnglishPrefix(_ word: Word) -> Bool {
        lexicon.hasEnglishPrefix(word.raw) || word.unquoted(word.raw).map(lexicon.hasEnglishPrefix) == true
    }

    /// An opener waiting for its second key, or an apostrophe that a letter would turn into tutuq.
    private func isPending(_ piece: Piece, in word: Word) -> Bool {
        guard !word.foreign, piece.raw == piece.shown, piece.raw.count == 1, let c = piece.raw.first else {
            return false
        }
        return Rules.isOpener(c) || c == "'"
    }

    private var inner: Engine {
        get {
            switch box {
            case .engine(let engine): return engine
            }
        }
        set { box = .engine(newValue) }
    }
}

/// Engine holds a MarkedComposer, so the composer keeps its engine out of line.
private indirect enum InnerEngine {
    case engine(Engine)
}
