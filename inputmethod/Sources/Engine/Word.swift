import Foundation

/// One typed unit: the raw keys and what the document shows for them (`sh` -> `ş`).
struct Piece: Equatable {
    var raw: String
    var shown: String
}

struct Word {
    var pieces: [Piece] = []
    /// False once the document stopped matching what we typed; no more replacements in this word.
    var tracking = true
    var foreign = false
    /// Piece count when the word turned foreign; Backspace below it clears `foreign`.
    var foreignAt = 0
    /// The `'` or backtick typed at the start of the word; only that mark can close it as a quote.
    var openedBy: Character?

    var raw: String { pieces.map(\.raw).joined() }
    var shown: String { pieces.map(\.shown).joined() }

    /// `text` without its last character when that closes the word's opening quote.
    /// Only the mark that opened the word closes it; `bog'` is the word `boğ`.
    func unquoted(_ text: String) -> String? {
        guard let opener = openedBy, text.last == opener else { return nil }
        return String(text.dropLast())
    }

    /// The last piece is o'/g' completed by the word's own opening mark: a closing quote if the word ends here.
    var endsWithQuoteDigraph: Bool {
        guard let mark = openedBy, let last = pieces.last, last.raw.count == 2, last.raw.last == mark,
              let opener = last.raw.first else { return false }
        return Rules.digraph(opener, mark) != nil
    }

    /// The word with such a final o'/g' split back into the letter and a plain closing mark.
    func closingQuoteSplit() -> Word {
        guard endsWithQuoteDigraph, let last = pieces.last else { return self }
        var word = self
        word.pieces.removeLast()
        word.pieces += last.raw.map { Piece(raw: String($0), shown: String($0)) }
        return word
    }

    /// What a client that ignores our replacements still shows: the first key of every digraph
    /// or converted piece (`sh` as `s`, a tutuq as `'`).
    func staleView() -> String {
        pieces.map { $0.raw.count > 1 || $0.raw != $0.shown ? String($0.raw.prefix(1)) : $0.shown }.joined()
    }
}
