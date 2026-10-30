#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace xattot {

// The engine counts text in code points, the C++ stand-in for Swift's Character:
// every key it sees types a single code point.
using Text = std::u32string;

Text fromUtf8(std::string_view utf8);
std::string toUtf8(const Text& text);

// Unpaired surrogates decode to U+FFFD, so a read that starts inside a pair stays one character.
Text fromUtf16(std::u16string_view utf16);
std::u16string toUtf16(const Text& text);
size_t utf16Length(const Text& text);

// General category L*, for the scripts a keyboard here can type (Latin, IPA and modifier
// letters, Greek, Cyrillic). U+02BC, the tutuq, is a modifier letter.
bool isLetter(char32_t c);

// Simple case mapping for the same scripts; the word lists are ASCII and Uzbek Latin.
char32_t toLower(char32_t c);
Text lowercased(const Text& text);

bool hasPrefix(const Text& text, const Text& prefix);
bool hasSuffix(const Text& text, const Text& suffix);

}  // namespace xattot
