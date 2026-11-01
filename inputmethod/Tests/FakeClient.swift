/// A text field stand-in: applies the engine's edits the way an input method host would.
struct FakeClient {
    var text = ""
    /// Character offset into `text`.
    var caret = 0
    /// Reports a shadow of the text that `.replace` never updates (Monaco's behaviour).
    var stale = false
    /// A passed `'` is inserted as the curly apostrophe.
    var smartQuotes = false

    private var shadow = ""
    private var markedLength = 0

    // Spelled out: the Swift on CI makes the memberwise init private because of the private fields.
    init(stale: Bool = false, smartQuotes: Bool = false) {
        self.stale = stale
        self.smartQuotes = smartQuotes
    }

    static func keys(_ notation: String) -> [Key] {
        var result: [Key] = []
        var option = false
        for c in notation {
            if c == "⌥" {
                option = true
                continue
            }
            defer { option = false }
            switch c {
            case "⌫": result.append(.named(.backspace))
            case "↵": result.append(.named(.returnKey))
            case "⇥": result.append(.named(.tab))
            case "⎋": result.append(.named(.escape))
            case "←": result.append(.named(.left))
            case "→": result.append(.named(.right))
            case "⌘": result.append(.shortcut)
            default: result.append(.character(c, option: option))
            }
        }
        return result
    }

    mutating func type(_ notation: String, into engine: inout Engine) {
        for key in Self.keys(notation) {
            apply(engine.handle(key), for: key, engine: &engine)
        }
    }

    /// Applies the edits of a word boundary that no key triggered.
    mutating func finish(_ engine: inout Engine) {
        apply(engine.endWord(), for: nil, engine: &engine)
    }

    private var shadowCaret: Int { caret + shadow.count - text.count }

    /// `fallback` marks the list `replacementFailed()` returned: it is applied once and may not replace.
    private mutating func apply(_ edits: [Edit], for key: Key?, engine: inout Engine, fallback: Bool = false) {
        if edits.filter(isReplace).count > 1 { check(false, "more than one replace in \(edits)") }
        for edit in edits {
            switch edit {
            case .pass:
                pass(key)
            case .insert(let s), .commit(let s):
                replaceMarked(with: s)
            case .setMarked(let s):
                replaceMarked(with: s)
                markedLength = s.count
            case .replace(let expected, let with):
                if fallback {
                    check(false, "replace inside a replacementFailed list")
                } else if !replace(expected: expected, with: with) {
                    // The fallback stands in for this .replace; the rest of the list still applies.
                    apply(engine.replacementFailed(), for: key, engine: &engine, fallback: true)
                }
            }
        }
    }

    private mutating func pass(_ key: Key?) {
        guard let key else {
            check(false, "pass without a key")
            return
        }
        switch key {
        case .character(let c, _):
            edit(removing: 0, inserting: c == "'" && smartQuotes ? "’" : String(c))
        case .named(.returnKey), .named(.enter):
            edit(removing: 0, inserting: "\n")
        case .named(.tab):
            edit(removing: 0, inserting: "\t")
        case .named(.left):
            caret = max(0, caret - 1)
        case .named(.right):
            caret = min(text.count, caret + 1)
        case .named(.backspace):
            edit(removing: 1, inserting: "")
        case .named(.escape), .named(.up), .named(.down), .shortcut:
            break
        }
    }

    private mutating func replaceMarked(with s: String) {
        edit(removing: markedLength, inserting: s)
        markedLength = 0
    }

    /// Removes characters before the caret and inserts text there, in the text and in the shadow.
    private mutating func edit(removing: Int, inserting: String) {
        let n = min(removing, caret, stale ? shadowCaret : caret)
        let at = shadowCaret
        text = Self.splice(text, caret: caret, removing: n, inserting: inserting)
        shadow = stale ? Self.splice(shadow, caret: at, removing: n, inserting: inserting) : text
        caret += inserting.count - n
    }

    private mutating func replace(expected: String, with: String) -> Bool {
        let seen = stale ? shadow : text
        let at = stale ? shadowCaret : caret
        guard at >= expected.count, at <= seen.count, caret >= expected.count,
            String(Array(seen)[(at - expected.count)..<at]) == expected
        else { return false }
        text = Self.splice(text, caret: caret, removing: expected.count, inserting: with)
        caret += with.count - expected.count
        if !stale { shadow = text }
        return true
    }

    private static func splice(_ s: String, caret: Int, removing: Int, inserting: String) -> String {
        var chars = Array(s)
        chars.replaceSubrange((caret - removing)..<caret, with: Array(inserting))
        return String(chars)
    }
}

func typed(
    _ notation: String, mode: Mode = .eager, lexicon: Lexicon = EmptyLexicon(),
    stale: Bool = false, smartQuotes: Bool = false
) -> String {
    var engine = Engine(lexicon: lexicon, mode: mode)
    var client = FakeClient(stale: stale, smartQuotes: smartQuotes)
    client.type(notation, into: &engine)
    client.finish(&engine)
    return client.text
}

func isReplace(_ edit: Edit) -> Bool {
    if case .replace = edit { return true }
    return false
}

func typedWithClick(_ before: String, clickAt: Int, then after: String) -> String {
    var engine = Engine()
    var client = FakeClient()
    client.type(before, into: &engine)
    client.caret = clickAt
    client.type(after, into: &engine)
    client.finish(&engine)
    return client.text
}
