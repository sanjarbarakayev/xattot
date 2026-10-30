#pragma once

#include <optional>
#include <vector>

#include "Text.h"

namespace xattot {

// One typed unit: the raw keys and what the document shows for them (`sh` -> `ş`).
struct Piece {
    Text raw;
    Text shown;

    static Piece plain(Text text) { return {text, text}; }
    bool operator==(const Piece&) const = default;
};

struct Word {
    std::vector<Piece> pieces;
    // False once the document stopped matching what we typed; no more replacements in this word.
    bool tracking = true;
    bool foreign = false;
    // Piece count when the word turned foreign; Backspace below it clears `foreign`.
    size_t foreignAt = 0;
    // The `'` or backtick typed at the start of the word; only that mark can close it as a quote.
    std::optional<char32_t> openedBy;

    Text raw() const;
    Text shown() const;

    // `text` without its last character when that closes the word's opening quote.
    // Only the mark that opened the word closes it; `bog'` is the word `boğ`.
    std::optional<Text> unquoted(const Text& text) const;

    // The last piece is o'/g' completed by the word's own opening mark: a closing quote if the word ends here.
    bool endsWithQuoteDigraph() const;

    // The word with such a final o'/g' split back into the letter and a plain closing mark.
    Word closingQuoteSplit() const;

    // What a client that ignores our replacements still shows: the first key of every digraph
    // or converted piece (`sh` as `s`, a tutuq as `'`).
    Text staleView() const;
};

}  // namespace xattot
