#pragma once

#include <optional>

#include "Text.h"

namespace xattot::rules {

// Uzbek Latin alphabet rules (law OʻRQ-1184), the same as inputmethod/Sources/Engine/Rules.swift.
inline constexpr char32_t tutuq = U'ʼ';

std::optional<char32_t> digraph(char32_t opener, char32_t next);
bool isOpener(char32_t c);
std::optional<Text> optionLetter(char32_t c);

// The alphabet has no w, and c only in ch: a word holding either is foreign.
bool isForeignLetter(char32_t c);
bool isForeignAfter(char32_t c);

}  // namespace xattot::rules
