#pragma once

#include <memory>
#include <string>

#include "../engine/AppModes.h"
#include "../engine/Engine.h"
#include "TextClient.h"

namespace xattot {

// Drives the engine against one text client at a time: applies its edits, verifies every
// replacement before making it, and keeps the engine in the mode `AppModes` picks for the app.
// The port of inputmethod/Sources/Host/HostSession.swift.
class HostSession {
public:
    HostSession(std::shared_ptr<const Lexicon> lexicon, std::shared_ptr<ModeStore> store);

    Mode mode() const { return engine_.mode(); }

    // Precondition: call `endWord` or `settle` first; activation drops the word.
    void activate(const std::string& app, TextClient& client);

    // True exactly when the applied edits do not end in `pass`: the input method eats the key.
    bool handle(const Key& key, TextClient& client);

    // What `handle` would return if every replacement check passed, without changing anything.
    // TSF asks before the key is handled (OnTestKeyDown), and a failed check can only turn an eaten
    // character key into a passed one.
    bool wouldEat(const Key& key) const;

    // A word boundary no key caused, such as a caret move or a commit request.
    void endWord(TextClient& client);

    // A boundary the session may have missed (a caret move, a focus change): commits the word
    // while the client still shows it marked, else drops it, since the client already holds the text.
    void settle(TextClient& client, bool showsMarked);

    // Deactivation or a commit request. A marked word is committed only while the client still shows it,
    // else the client already finalized it; an eager word ends as usual, every edit verified.
    void endWord(TextClient& client, bool showsMarked);

    // The client is gone: drop the word without editing anything.
    void reset();

private:
    Engine engine_;
    AppModes modes_;
    // Empty until the first activation.
    std::string app_;

    bool apply(const Edits& edits, TextClient& client, bool fallback = false);
    bool replace(const Text& expected, const Text& text, TextClient& client);
    void syncMode(TextClient& client);
};

}  // namespace xattot
