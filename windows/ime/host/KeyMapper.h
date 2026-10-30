#pragma once

#include <optional>

#include "../engine/Key.h"

namespace xattot {

// What the text service knows about a WM_KEYDOWN, free of Windows types.
struct KeyFacts {
    unsigned virtualKey = 0;
    // The extended-key flag of the scan code: numpad Enter is VK_RETURN with it set.
    bool extended = false;
    bool control = false;
    bool alt = false;
    // What the key types through the base layout with Shift and Caps Lock but without Ctrl or Alt;
    // nullopt when it types nothing.
    std::optional<char32_t> text;
};

namespace keymapper {

// nullopt means the key is not ours: pass it on untouched, leave the word alone.
// AltGr (Ctrl+Alt) is the option key: AltGr+S types Ş, as Option+S does on the Mac.
std::optional<Key> key(const KeyFacts& facts);

}  // namespace keymapper

}  // namespace xattot
