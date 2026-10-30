#include "Word.h"

#include "Rules.h"

namespace xattot {

Text Word::raw() const {
    Text out;
    for (const Piece& piece : pieces) out += piece.raw;
    return out;
}

Text Word::shown() const {
    Text out;
    for (const Piece& piece : pieces) out += piece.shown;
    return out;
}

std::optional<Text> Word::unquoted(const Text& text) const {
    if (!openedBy || text.empty() || text.back() != *openedBy) return std::nullopt;
    return text.substr(0, text.size() - 1);
}

bool Word::endsWithQuoteDigraph() const {
    if (!openedBy || pieces.empty()) return false;
    const Piece& last = pieces.back();
    if (last.raw.size() != 2 || last.raw.back() != *openedBy) return false;
    return rules::digraph(last.raw.front(), *openedBy).has_value();
}

Word Word::closingQuoteSplit() const {
    if (!endsWithQuoteDigraph()) return *this;
    Word word = *this;
    const Piece last = word.pieces.back();
    word.pieces.pop_back();
    for (char32_t c : last.raw) word.pieces.push_back(Piece::plain(Text(1, c)));
    return word;
}

Text Word::staleView() const {
    Text out;
    for (const Piece& piece : pieces) {
        out += piece.raw.size() > 1 || piece.raw != piece.shown ? piece.raw.substr(0, 1) : piece.shown;
    }
    return out;
}

}  // namespace xattot
