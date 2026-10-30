#pragma once

#include "Text.h"

namespace xattot {

enum class NamedKey { returnKey, enter, tab, escape, left, right, up, down, backspace };

// A key as the host reports it to `Engine::handle`.
// - An option key (AltGr or Ctrl+Alt on Windows) carries the character typed without it, Shift applied.
// - Ctrl or Alt combinations, a modified Backspace, Delete and Home/End/Page keys are `shortcut`.
// - A caret or focus change the engine did not cause is no key: the host calls `Engine::endWord()`,
//   or `Engine::reset()` when the client is gone.
struct Key {
    enum class Kind { character, named, shortcut };

    Kind kind = Kind::shortcut;
    char32_t character = 0;
    bool option = false;
    NamedKey named = NamedKey::escape;

    static Key typed(char32_t c, bool option = false) { return {Kind::character, c, option, NamedKey::escape}; }
    static Key press(NamedKey n) { return {Kind::named, 0, false, n}; }
    static Key shortcut() { return {}; }

    bool isCharacter(bool withOption) const { return kind == Kind::character && option == withOption; }
    bool is(NamedKey n) const { return kind == Kind::named && named == n; }
    bool operator==(const Key&) const = default;
};

enum class Mode { eager, marked };

}  // namespace xattot
