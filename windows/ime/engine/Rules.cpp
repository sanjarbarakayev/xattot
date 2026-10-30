#include "Rules.h"

namespace xattot::rules {

std::optional<char32_t> digraph(char32_t opener, char32_t next) {
    // Capital openers accept a capital H as well.
    switch (opener) {
    case U'c': return next == U'h' ? std::optional(U'ç') : std::nullopt;
    case U'C': return next == U'h' || next == U'H' ? std::optional(U'Ç') : std::nullopt;
    case U's': return next == U'h' ? std::optional(U'ş') : std::nullopt;
    case U'S': return next == U'h' || next == U'H' ? std::optional(U'Ş') : std::nullopt;
    case U'o': return next == U'\'' || next == U'`' ? std::optional(U'ö') : std::nullopt;
    case U'O': return next == U'\'' || next == U'`' ? std::optional(U'Ö') : std::nullopt;
    case U'g': return next == U'\'' || next == U'`' ? std::optional(U'ğ') : std::nullopt;
    case U'G': return next == U'\'' || next == U'`' ? std::optional(U'Ğ') : std::nullopt;
    default: return std::nullopt;
    }
}

bool isOpener(char32_t c) {
    return c == U'c' || c == U'C' || c == U's' || c == U'S' || c == U'o' || c == U'O' || c == U'g' || c == U'G';
}

// Option+H types a plain h that never completes a digraph (s, Option+H gives "sh").
// Shift+Option+' arrives as the quote character and also types tutuq.
std::optional<Text> optionLetter(char32_t c) {
    switch (c) {
    case U'c': return Text(U"ç");
    case U'C': return Text(U"Ç");
    case U's': return Text(U"ş");
    case U'S': return Text(U"Ş");
    case U'g': return Text(U"ğ");
    case U'G': return Text(U"Ğ");
    case U'o': return Text(U"ö");
    case U'O': return Text(U"Ö");
    case U'h': return Text(U"h");
    case U'H': return Text(U"H");
    case U'\'':
    case U'"': return Text(1, tutuq);
    default: return std::nullopt;
    }
}

bool isForeignLetter(char32_t c) {
    return c == U'w' || c == U'W';
}

bool isForeignAfter(char32_t c) {
    return c == U'c' || c == U'C';
}

}  // namespace xattot::rules
