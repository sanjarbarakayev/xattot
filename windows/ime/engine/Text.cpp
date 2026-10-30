#include "Text.h"

namespace xattot {

namespace {

constexpr char32_t replacement = 0xFFFD;

bool between(char32_t c, char32_t low, char32_t high) {
    return c >= low && c <= high;
}

}  // namespace

Text fromUtf8(std::string_view utf8) {
    Text out;
    out.reserve(utf8.size());
    size_t i = 0;
    while (i < utf8.size()) {
        const auto lead = static_cast<unsigned char>(utf8[i]);
        int extra = lead < 0x80 ? 0 : (lead >> 5) == 0x6 ? 1 : (lead >> 4) == 0xE ? 2 : (lead >> 3) == 0x1E ? 3 : -1;
        if (extra < 0 || i + extra >= utf8.size()) {
            out.push_back(replacement);
            ++i;
            continue;
        }
        char32_t c = extra == 0 ? lead : lead & (0x3F >> extra);
        bool valid = true;
        for (int k = 1; k <= extra; ++k) {
            const auto next = static_cast<unsigned char>(utf8[i + k]);
            if ((next & 0xC0) != 0x80) {
                valid = false;
                break;
            }
            c = (c << 6) | (next & 0x3F);
        }
        out.push_back(valid ? c : replacement);
        i += valid ? extra + 1 : 1;
    }
    return out;
}

std::string toUtf8(const Text& text) {
    std::string out;
    out.reserve(text.size());
    for (char32_t c : text) {
        if (c < 0x80) {
            out.push_back(static_cast<char>(c));
        } else if (c < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (c >> 6)));
            out.push_back(static_cast<char>(0x80 | (c & 0x3F)));
        } else if (c < 0x10000) {
            out.push_back(static_cast<char>(0xE0 | (c >> 12)));
            out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (c & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xF0 | (c >> 18)));
            out.push_back(static_cast<char>(0x80 | ((c >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((c >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (c & 0x3F)));
        }
    }
    return out;
}

Text fromUtf16(std::u16string_view utf16) {
    Text out;
    out.reserve(utf16.size());
    for (size_t i = 0; i < utf16.size(); ++i) {
        const char16_t unit = utf16[i];
        if (between(unit, 0xD800, 0xDBFF) && i + 1 < utf16.size() && between(utf16[i + 1], 0xDC00, 0xDFFF)) {
            out.push_back(0x10000 + ((unit - 0xD800) << 10) + (utf16[i + 1] - 0xDC00));
            ++i;
        } else if (between(unit, 0xD800, 0xDFFF)) {
            out.push_back(replacement);
        } else {
            out.push_back(unit);
        }
    }
    return out;
}

std::u16string toUtf16(const Text& text) {
    std::u16string out;
    out.reserve(text.size());
    for (char32_t c : text) {
        if (c < 0x10000) {
            out.push_back(static_cast<char16_t>(c));
        } else {
            out.push_back(static_cast<char16_t>(0xD800 + ((c - 0x10000) >> 10)));
            out.push_back(static_cast<char16_t>(0xDC00 + ((c - 0x10000) & 0x3FF)));
        }
    }
    return out;
}

size_t utf16Length(const Text& text) {
    size_t units = 0;
    for (char32_t c : text) units += c < 0x10000 ? 1 : 2;
    return units;
}

bool isLetter(char32_t c) {
    if (between(c, 'A', 'Z') || between(c, 'a', 'z')) return true;
    if (c < 0xAA) return false;
    if (c == 0xAA || c == 0xB5 || c == 0xBA) return true;
    if (between(c, 0xC0, 0x24F)) return c != 0xD7 && c != 0xF7;
    if (between(c, 0x250, 0x2C1) || between(c, 0x2C6, 0x2D1) || between(c, 0x2E0, 0x2E4)) return true;
    if (c == 0x2EC || c == 0x2EE) return true;
    if (between(c, 0x370, 0x3FF)) {
        return between(c, 0x370, 0x374) || c == 0x376 || c == 0x377 || between(c, 0x37A, 0x37D) || c == 0x37F ||
               c == 0x386 || between(c, 0x388, 0x38A) || c == 0x38C || between(c, 0x38E, 0x3A1) ||
               between(c, 0x3A3, 0x3F5) || between(c, 0x3F7, 0x3FF);
    }
    if (between(c, 0x400, 0x481) || between(c, 0x48A, 0x52F)) return true;
    return between(c, 0x1E00, 0x1EFF);
}

char32_t toLower(char32_t c) {
    if (between(c, 'A', 'Z')) return c + 0x20;
    if (c < 0xC0) return c;
    if (between(c, 0xC0, 0xDE)) return c == 0xD7 ? c : c + 0x20;
    if (c == 0x130) return 'i';
    if (c == 0x178) return 0xFF;
    if (between(c, 0x100, 0x137) || between(c, 0x14A, 0x177)) return c % 2 == 0 ? c + 1 : c;
    if (between(c, 0x139, 0x148) || between(c, 0x179, 0x17E)) return c % 2 == 1 ? c + 1 : c;
    if (between(c, 0x391, 0x3A1) || between(c, 0x3A3, 0x3AB)) return c + 0x20;
    if (between(c, 0x400, 0x40F)) return c + 0x50;
    if (between(c, 0x410, 0x42F)) return c + 0x20;
    if (between(c, 0x460, 0x481) || between(c, 0x48A, 0x4BF) || between(c, 0x4D0, 0x52F)) return c % 2 == 0 ? c + 1 : c;
    if (c == 0x4C0) return 0x4CF;
    if (between(c, 0x4C1, 0x4CE)) return c % 2 == 1 ? c + 1 : c;
    if (between(c, 0x1E00, 0x1EFF)) return c % 2 == 0 ? c + 1 : c;
    return c;
}

Text lowercased(const Text& text) {
    Text out = text;
    for (char32_t& c : out) c = toLower(c);
    return out;
}

bool hasPrefix(const Text& text, const Text& prefix) {
    return text.size() >= prefix.size() && text.compare(0, prefix.size(), prefix) == 0;
}

bool hasSuffix(const Text& text, const Text& suffix) {
    return text.size() >= suffix.size() && text.compare(text.size() - suffix.size(), suffix.size(), suffix) == 0;
}

}  // namespace xattot
