#include "FakeClient.h"

#include <algorithm>

#include "Check.h"

namespace xattot::test {

namespace {

Text splice(const Text& s, size_t caret, size_t removing, const Text& inserting) {
    return s.substr(0, caret - removing) + inserting + s.substr(caret);
}

}  // namespace

std::vector<Key> keys(const std::string& notation) {
    std::vector<Key> result;
    bool option = false;
    for (char32_t c : fromUtf8(notation)) {
        if (c == U'⌥') {
            option = true;
            continue;
        }
        switch (c) {
        case U'⌫': result.push_back(Key::press(NamedKey::backspace)); break;
        case U'↵': result.push_back(Key::press(NamedKey::returnKey)); break;
        case U'⇥': result.push_back(Key::press(NamedKey::tab)); break;
        case U'⎋': result.push_back(Key::press(NamedKey::escape)); break;
        case U'←': result.push_back(Key::press(NamedKey::left)); break;
        case U'→': result.push_back(Key::press(NamedKey::right)); break;
        case U'⌘': result.push_back(Key::shortcut()); break;
        default: result.push_back(Key::typed(c, option)); break;
        }
        option = false;
    }
    return result;
}

void FakeClient::type(const std::string& notation, Engine& engine) {
    for (const Key& key : keys(notation)) {
        const Edits edits = engine.handle(key);
        if (onEdits) onEdits(edits);
        apply(edits, &key, engine);
    }
}

void FakeClient::finish(Engine& engine) {
    const Edits edits = engine.endWord();
    if (onEdits) onEdits(edits);
    apply(edits, nullptr, engine);
}

// `fallback` marks the list `replacementFailed()` returned: it is applied once and may not replace.
void FakeClient::apply(const Edits& edits, const Key* key, Engine& engine, bool fallback) {
    const auto replaces = std::count_if(edits.begin(), edits.end(), [](const Edit& e) { return e.kind == Edit::Kind::replace; });
    if (replaces > 1) check(false, "more than one replace in one edit list");
    for (const Edit& e : edits) {
        switch (e.kind) {
        case Edit::Kind::pass:
            pass(key);
            break;
        case Edit::Kind::insert:
        case Edit::Kind::commit:
            replaceMarked(e.text);
            break;
        case Edit::Kind::setMarked:
            replaceMarked(e.text);
            markedLength_ = e.text.size();
            break;
        case Edit::Kind::replace:
            if (fallback) {
                check(false, "replace inside a replacementFailed list");
            } else if (!replace(e.expected, e.text)) {
                // The fallback stands in for this replace; the rest of the list still applies.
                const Edits recovered = engine.replacementFailed();
                if (onEdits) onEdits(recovered);
                apply(recovered, key, engine, true);
            }
            break;
        }
    }
}

void FakeClient::pass(const Key* key) {
    if (!key) {
        check(false, "pass without a key");
        return;
    }
    switch (key->kind) {
    case Key::Kind::character:
        edit(0, key->character == U'\'' && smartQuotes ? Text(U"’") : Text(1, key->character));
        break;
    case Key::Kind::named:
        switch (key->named) {
        case NamedKey::returnKey:
        case NamedKey::enter: edit(0, U"\n"); break;
        case NamedKey::tab: edit(0, U"\t"); break;
        case NamedKey::left: caret = caret > 0 ? caret - 1 : 0; break;
        case NamedKey::right: caret = std::min(text.size(), caret + 1); break;
        case NamedKey::backspace: edit(1, U""); break;
        case NamedKey::escape:
        case NamedKey::up:
        case NamedKey::down: break;
        }
        break;
    case Key::Kind::shortcut:
        break;
    }
}

void FakeClient::replaceMarked(const Text& s) {
    edit(markedLength_, s);
    markedLength_ = 0;
}

// Removes characters before the caret and inserts text there, in the text and in the shadow.
void FakeClient::edit(size_t removing, const Text& inserting) {
    const size_t n = std::min({removing, caret, stale ? shadowCaret() : caret});
    const size_t at = shadowCaret();
    text = splice(text, caret, n, inserting);
    shadow_ = stale ? splice(shadow_, at, n, inserting) : text;
    caret = caret + inserting.size() - n;
}

bool FakeClient::replace(const Text& expected, const Text& with) {
    const Text& seen = stale ? shadow_ : text;
    const size_t at = stale ? shadowCaret() : caret;
    if (at < expected.size() || at > seen.size() || caret < expected.size()) return false;
    if (seen.compare(at - expected.size(), expected.size(), expected) != 0) return false;
    text = splice(text, caret, expected.size(), with);
    caret = caret + with.size() - expected.size();
    if (!stale) shadow_ = text;
    return true;
}

std::string typed(const std::string& notation, const Options& options) {
    Engine engine(options.lexicon ? options.lexicon : std::make_shared<EmptyLexicon>(), options.mode);
    FakeClient client;
    client.stale = options.stale;
    client.smartQuotes = options.smartQuotes;
    client.type(notation, engine);
    client.finish(engine);
    return toUtf8(client.text);
}

}  // namespace xattot::test
