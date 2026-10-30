#pragma once

#include <functional>
#include <string>
#include <vector>

#include "../engine/Engine.h"

namespace xattot::test {

// Keys from the Swift tests' notation: ⌥ makes the next character an option key,
// ⌫ ↵ ⇥ ⎋ ← → are named keys and ⌘ is a shortcut.
std::vector<Key> keys(const std::string& notation);

// A text field stand-in: applies the engine's edits the way an input method host would.
// The port of inputmethod/Tests/FakeClient.swift.
class FakeClient {
public:
    Text text;
    // Character offset into `text`.
    size_t caret = 0;
    // Reports a shadow of the text that `replace` never updates (Monaco's behaviour).
    bool stale = false;
    // A passed `'` is inserted as the curly apostrophe.
    bool smartQuotes = false;
    // Called with every edit list the engine returns, for the cross-check.
    std::function<void(const Edits&)> onEdits;

    void type(const std::string& notation, Engine& engine);
    // Applies the edits of a word boundary that no key triggered.
    void finish(Engine& engine);

private:
    Text shadow_;
    size_t markedLength_ = 0;

    size_t shadowCaret() const { return caret + shadow_.size() - text.size(); }
    void apply(const Edits& edits, const Key* key, Engine& engine, bool fallback = false);
    void pass(const Key* key);
    void replaceMarked(const Text& s);
    void edit(size_t removing, const Text& inserting);
    bool replace(const Text& expected, const Text& with);
};

struct Options {
    Mode mode = Mode::eager;
    std::shared_ptr<const Lexicon> lexicon;
    bool stale = false;
    bool smartQuotes = false;
};

std::string typed(const std::string& notation, const Options& options = {});

}  // namespace xattot::test
