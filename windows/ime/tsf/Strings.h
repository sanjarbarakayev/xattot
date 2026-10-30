#pragma once

#include <string>

#include "../engine/Text.h"

namespace xattot::tsf {

// wchar_t is UTF-16 on Windows.
inline std::wstring toWide(const Text& text) {
    const std::u16string units = toUtf16(text);
    return std::wstring(units.begin(), units.end());
}

inline std::wstring toWide(const std::string& utf8) {
    return toWide(fromUtf8(utf8));
}

inline Text fromWide(const std::wstring& wide) {
    return fromUtf16(std::u16string(wide.begin(), wide.end()));
}

inline std::string toUtf8(const std::wstring& wide) {
    return xattot::toUtf8(fromWide(wide));
}

}  // namespace xattot::tsf
