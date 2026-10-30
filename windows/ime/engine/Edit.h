#pragma once

#include <vector>

#include "Text.h"

namespace xattot {

// Applied in order. `pass` is always last: the input method does not eat the key
// and the app types it itself. A list holds at most one `replace`.
struct Edit {
    enum class Kind {
        pass,
        // Inserts `text` at the caret; the key is consumed.
        insert,
        // Replaces exactly `expected`, the text immediately before the caret, only after reading it back
        // to verify it. If it differs, the host replaces nothing, calls `Engine::replacementFailed()`
        // and applies the edits it returns in place of this one.
        replace,
        // Sets the marked text (the composition); an empty `text` clears it.
        setMarked,
        // Replaces the current marked range (or inserts at the caret if none) and ends composition.
        commit,
    };

    Kind kind = Kind::pass;
    Text text;
    Text expected;

    static Edit pass() { return {}; }
    static Edit insert(Text t) { return {Kind::insert, std::move(t), {}}; }
    static Edit replace(Text expected, Text with) { return {Kind::replace, std::move(with), std::move(expected)}; }
    static Edit setMarked(Text t) { return {Kind::setMarked, std::move(t), {}}; }
    static Edit commit(Text t) { return {Kind::commit, std::move(t), {}}; }

    bool operator==(const Edit&) const = default;
};

using Edits = std::vector<Edit>;

inline Edits operator+(Edits a, const Edits& b) {
    a.insert(a.end(), b.begin(), b.end());
    return a;
}

}  // namespace xattot
