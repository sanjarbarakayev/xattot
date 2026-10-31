#include "HostSession.h"

namespace xattot {

HostSession::HostSession(std::shared_ptr<const Lexicon> lexicon, std::shared_ptr<ModeStore> store)
    : engine_(std::move(lexicon)), modes_(std::move(store)) {}

void HostSession::activate(const std::string& app, TextClient& client) {
    app_ = app;
    engine_.reset();
    syncMode(client);
}

bool HostSession::handle(const Key& key, TextClient& client) {
    syncMode(client);
    return !apply(engine_.handle(key), client);
}

bool HostSession::wouldEat(const Key& key) const {
    Engine engine = engine_;
    Edits edits;
    const Mode target = modes_.mode(app_);
    if (target != engine.mode()) edits = engine.switchMode(target);
    edits = edits + engine.handle(key);
    return edits.empty() || edits.back().kind != Edit::Kind::pass;
}

void HostSession::endWord(TextClient& client) {
    syncMode(client);
    apply(engine_.endWord(), client);
}

void HostSession::settle(TextClient& client, bool showsMarked) {
    if (showsMarked) {
        endWord(client);
    } else {
        reset();
    }
}

void HostSession::endWord(TextClient& client, bool showsMarked) {
    if (engine_.mode() == Mode::marked && !showsMarked) {
        reset();
    } else {
        endWord(client);
    }
}

void HostSession::reset() {
    engine_.reset();
}

// Returns whether the last applied edit was `pass`. `fallback` marks the list
// `replacementFailed()` returned, which never replaces.
bool HostSession::apply(const Edits& edits, TextClient& client, bool fallback) {
    bool passed = false;
    for (const Edit& edit : edits) {
        passed = false;
        switch (edit.kind) {
        case Edit::Kind::pass: passed = true; break;
        case Edit::Kind::insert: client.insert(edit.text); break;
        case Edit::Kind::setMarked: client.setMarked(edit.text); break;
        case Edit::Kind::commit: client.commit(edit.text); break;
        case Edit::Kind::replace:
            // A replace in a fallback list has no recovery left, so it edits nothing.
            if (fallback) break;
            if (!replace(edit.expected, edit.text, client)) passed = apply(engine_.replacementFailed(), client, true);
            break;
        }
    }
    return passed;
}

// The read before a replacement is the only read: right after one, Chromium still shows old text.
// A refused write counts as no text, so an app that refuses every write ends up marked for the session.
bool HostSession::replace(const Text& expected, const Text& text, TextClient& client) {
    std::optional<Text> found = client.textBefore(expected.size());
    if (found == expected) {
        if (client.replace(expected.size(), text)) return true;
        found.reset();
    }
    if (const auto& last = engine_.lastReplacement()) modes_.observe(app_, found, last->expected, last->staleView);
    return false;
}

// Runs before the engine sees the next key or boundary, so a flush from the switch always lands
// ahead of it. A mode learned mid-key therefore takes effect from the next key.
void HostSession::syncMode(TextClient& client) {
    const Mode target = modes_.mode(app_);
    if (target == engine_.mode()) return;
    apply(engine_.switchMode(target), client);
}

}  // namespace xattot
