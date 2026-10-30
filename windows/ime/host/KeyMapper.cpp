#include "KeyMapper.h"

namespace xattot::keymapper {

namespace {

// Virtual-key codes from WinUser.h, so the mapping builds and is tested on any platform.
enum : unsigned {
    vkBack = 0x08, vkTab = 0x09, vkReturn = 0x0D, vkShift = 0x10, vkControl = 0x11, vkMenu = 0x12,
    vkPause = 0x13, vkCapital = 0x14, vkEscape = 0x1B, vkPrior = 0x21, vkNext = 0x22, vkEnd = 0x23,
    vkHome = 0x24, vkLeft = 0x25, vkUp = 0x26, vkRight = 0x27, vkDown = 0x28, vkInsert = 0x2D,
    vkDelete = 0x2E, vkLWin = 0x5B, vkApps = 0x5D, vkF1 = 0x70, vkF24 = 0x87, vkNumLock = 0x90,
    vkScroll = 0x91, vkLShift = 0xA0, vkRMenu = 0xA5,
};

std::optional<NamedKey> named(unsigned vk, bool extended) {
    switch (vk) {
    case vkReturn: return extended ? NamedKey::enter : NamedKey::returnKey;
    case vkTab: return NamedKey::tab;
    case vkEscape: return NamedKey::escape;
    case vkLeft: return NamedKey::left;
    case vkRight: return NamedKey::right;
    case vkUp: return NamedKey::up;
    case vkDown: return NamedKey::down;
    case vkBack: return NamedKey::backspace;
    default: return std::nullopt;
    }
}

bool isNavigation(unsigned vk) {
    return vk == vkDelete || vk == vkHome || vk == vkEnd || vk == vkPrior || vk == vkNext || vk == vkInsert;
}

// Modifiers, locks and function keys carry no text and never touch a word.
bool isSilent(unsigned vk) {
    return vk == vkShift || vk == vkControl || vk == vkMenu || vk == vkCapital || vk == vkPause ||
           vk == vkLWin || vk == vkLWin + 1 || vk == vkApps || vk == vkNumLock || vk == vkScroll ||
           (vk >= vkLShift && vk <= vkRMenu) || (vk >= vkF1 && vk <= vkF24);
}

// Text the user types; control and private-use code points are not.
std::optional<char32_t> typed(std::optional<char32_t> text) {
    if (!text) return std::nullopt;
    const char32_t c = *text;
    if (c < 0x20 || c == 0x7F || (c >= 0xE000 && c <= 0xF8FF)) return std::nullopt;
    return c;
}

}  // namespace

std::optional<Key> key(const KeyFacts& facts) {
    if (const auto n = named(facts.virtualKey, facts.extended)) {
        if (facts.control || facts.alt) return Key::shortcut();
        return Key::press(*n);
    }
    if (isSilent(facts.virtualKey)) return std::nullopt;
    if (isNavigation(facts.virtualKey)) return Key::shortcut();
    if (facts.control && facts.alt) {
        const auto c = typed(facts.text);
        if (!c) return std::nullopt;
        return Key::typed(*c, true);
    }
    if (facts.control || facts.alt) return Key::shortcut();
    const auto c = typed(facts.text);
    if (!c) return std::nullopt;
    return Key::typed(*c);
}

}  // namespace xattot::keymapper
