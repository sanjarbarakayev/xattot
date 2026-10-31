#include <set>

#include "../host/HostSession.h"
#include "../host/KeyMapper.h"
#include "../host/Utf16Text.h"
#include "Check.h"
#include "FakeClient.h"
#include "Tests.h"

namespace xattot::test {

namespace {

// A text field behind `TextClient`, for driving a `HostSession` the way an app would.
// The port of inputmethod/Tests/HostTestClient.swift, plus a document that refuses writes.
class HostTestClient final : public TextClient {
public:
    Text text;
    size_t caret = 0;
    bool stale = false;
    bool reportsNil = false;
    bool refusesWrites = false;
    int replaceCount = 0;
    std::vector<Text> commits;

    explicit HostTestClient(Text initial = U"") : text(initial), caret(initial.size()), shadow_(initial) {}

    Text marked() const { return text.substr(caret - markedLength_, markedLength_); }
    bool showsMarked() const { return markedLength_ > 0; }

    void click(size_t offset) {
        caret = offset;
        markedLength_ = 0;
    }

    void finalizeMarked() { markedLength_ = 0; }

    void type(const std::string& notation, HostSession& session) {
        for (const Key& key : keys(notation)) {
            if (!session.handle(key, *this)) typeItself(key);
        }
    }

    void typeItself(const Key& key) {
        if (key.kind == Key::Kind::character) {
            edit(0, Text(1, key.character));
        } else if (key.is(NamedKey::returnKey) || key.is(NamedKey::enter)) {
            edit(0, U"\n");
        } else if (key.is(NamedKey::tab)) {
            edit(0, U"\t");
        } else if (key.is(NamedKey::backspace)) {
            edit(1, U"");
        } else if (key.is(NamedKey::left)) {
            caret = caret > 0 ? caret - 1 : 0;
        } else if (key.is(NamedKey::right)) {
            caret = std::min(text.size(), caret + 1);
        }
    }

    std::optional<Text> textBefore(size_t length) override {
        if (reportsNil) return std::nullopt;
        const Text& seen = stale ? shadow_ : text;
        const size_t at = stale ? shadowCaret() : caret;
        const size_t from = at > length ? at - length : 0;
        return seen.substr(from, at - from);
    }

    bool replace(size_t length, const Text& replacement) override {
        ++replaceCount;
        if (refusesWrites) return false;
        text = text.substr(0, caret - length) + replacement + text.substr(caret);
        caret = caret + replacement.size() - length;
        if (!stale) shadow_ = text;
        return true;
    }

    void insert(const Text& inserted) override { replaceMarked(inserted); }

    void setMarked(const Text& marked) override {
        replaceMarked(marked);
        markedLength_ = marked.size();
    }

    void commit(const Text& committed) override {
        commits.push_back(committed);
        replaceMarked(committed);
    }

private:
    Text shadow_;
    size_t markedLength_ = 0;

    size_t shadowCaret() const { return caret + shadow_.size() - text.size(); }

    void replaceMarked(const Text& s) {
        edit(markedLength_, s);
        markedLength_ = 0;
    }

    void edit(size_t removing, const Text& inserting) {
        const size_t n = std::min({removing, caret, stale ? shadowCaret() : caret});
        const size_t at = shadowCaret();
        text = text.substr(0, caret - n) + inserting + text.substr(caret);
        shadow_ = stale ? shadow_.substr(0, at - n) + inserting + shadow_.substr(at) : text;
        caret = caret + inserting.size() - n;
    }
};

class SessionStore final : public ModeStore {
public:
    std::set<std::string> saved;
    int saveCount = 0;
    std::set<std::string> learnedMarkedApps() const override { return saved; }
    void learnMarkedApp(const std::string& app) override {
        saved.insert(app);
        ++saveCount;
    }
    void forgetMarkedApp(const std::string& app) override {
        saved.erase(app);
        ++saveCount;
    }
};

std::shared_ptr<const Lexicon> pushLexicon() {
    return std::make_shared<WordListLexicon>(std::vector<Text>{U"push"}, std::vector<Text>{});
}

HostSession session(HostTestClient& client, const std::string& app = "",
                    std::shared_ptr<const Lexicon> lexicon = nullptr,
                    std::shared_ptr<SessionStore> store = std::make_shared<SessionStore>()) {
    HostSession host(lexicon ? lexicon : std::make_shared<EmptyLexicon>(), store);
    if (!app.empty()) host.activate(app, client);
    return host;
}

void runSessionTests() {
    {
        HostTestClient client;
        auto host = session(client, "telegram.exe");
        client.type("shahar o'g'il", host);
        host.endWord(client);
        check(client.text == U"şahar öğil", "host: eager typing converts");
    }
    {
        HostTestClient client;
        auto host = session(client, "telegram.exe", pushLexicon());
        client.type("push ", host);
        check(client.text == U"push ", "host: the English guard restores push");
    }
    {
        HostTestClient client;
        auto host = session(client);
        client.type("pus", host);
        client.click(1);
        client.type("hsh", host);
        check(client.text == U"phshus" && client.replaceCount == 0, "host: an unreported caret move fails every check");
    }
    {
        auto store = std::make_shared<SessionStore>();
        HostTestClient client;
        client.stale = true;
        auto host = session(client, "x.exe", nullptr, store);
        client.type("shs", host);
        const bool eaten = host.handle(Key::typed(U'h'), client);
        check(!eaten && client.replaceCount == 1, "host: a failed digraph check passes the key");
        check(store->saved == std::set<std::string>{"x.exe"} && host.mode() == Mode::eager,
              "host: a failed check learns the app, effective from the next key");
        client.typeItself(Key::typed(U'h'));
        client.type(" sh", host);
        host.endWord(client);
        check(host.mode() == Mode::marked && client.text == U"şsh ş" && client.replaceCount == 1,
              "host: the next word composes in marked mode");
    }
    {
        auto store = std::make_shared<SessionStore>();
        HostTestClient client;
        client.reportsNil = true;
        auto host = session(client, "notepad.exe", nullptr, store);
        client.type("sh sh", host);
        check(host.mode() == Mode::eager, "host: two nil reports keep eager");
        client.type(" sh", host);
        host.endWord(client);
        check(host.mode() == Mode::marked && store->saveCount == 0 && client.text == U"sh sh sh",
              "host: three nil reports mark the app for the session, editing nothing");
    }
    {
        auto store = std::make_shared<SessionStore>();
        HostTestClient client;
        client.refusesWrites = true;
        auto host = session(client, "legacy.exe", nullptr, store);
        client.type("sh sh sh", host);
        host.endWord(client);
        check(client.text == U"sh sh sh" && client.replaceCount == 3, "host: refused writes pass the key");
        check(host.mode() == Mode::marked && store->saveCount == 0,
              "host: an app that refuses writes goes marked for the session");
    }
    {
        HostTestClient client;
        auto host = session(client, "code.exe");
        check(host.mode() == Mode::marked, "host: VS Code starts marked");
        client.type("o'g'il s", host);
        check(client.marked() == U"s", "host: a pending opener is marked");
        host.endWord(client);
        check(client.text == U"öğil s" && client.marked().empty() && client.replaceCount == 0,
              "host: marked typing commits");
    }
    {
        HostTestClient client;
        auto host = session(client, "code.exe");
        client.type("s", host);
        client.finalizeMarked();
        host.settle(client, client.showsMarked());
        host.activate("code.exe", client);
        client.type("h", host);
        host.endWord(client);
        check(client.text == U"sh" && client.commits.empty(),
              "host: text the client already finalized is not inserted again");
    }
    {
        HostTestClient client;
        auto host = session(client, "code.exe");
        client.type("s", host);
        host.endWord(client, client.showsMarked());
        check(client.text == U"s" && client.commits == std::vector<Text>{U"s"},
              "host: ending a shown marked word commits it once");
    }
    {
        HostTestClient client;
        auto host = session(client, "telegram.exe", pushLexicon());
        client.type("push", host);
        host.endWord(client, client.showsMarked());
        check(client.text == U"push", "host: leaving an eager word still restores an English word");
    }
    {
        HostTestClient client;
        auto host = session(client, "telegram.exe");
        client.type("s", host);
        host.reset();
        client.type("h", host);
        check(client.text == U"sh" && client.replaceCount == 0, "host: reset forgets the word");
    }
}

void runWouldEatTests() {
    HostTestClient client;
    auto host = session(client, "telegram.exe", pushLexicon());
    check(!host.wouldEat(Key::typed(U'p')), "eat: a plain letter passes");
    client.type("pus", host);
    check(host.wouldEat(Key::typed(U'h')), "eat: a completed digraph is eaten");
    check(client.text == U"pus", "eat: asking changes nothing");
    check(!host.wouldEat(Key::typed(U' ')) && !host.wouldEat(Key::press(NamedKey::returnKey)),
          "eat: a boundary key reaches the app after the guard");
    check(host.wouldEat(Key::typed(U's', true)), "eat: an option letter is inserted by the input method");
    check(!host.wouldEat(Key::typed(U'e', true)), "eat: an unmapped option key passes");

    HostTestClient editor;
    auto marked = session(editor, "code.exe");
    check(marked.wouldEat(Key::typed(U's')), "eat: a marked opener is eaten");
    check(!marked.wouldEat(Key::typed(U'a')), "eat: a plain letter passes in marked mode");
    editor.type("s", marked);
    check(marked.wouldEat(Key::press(NamedKey::backspace)), "eat: Backspace inside the marked text is eaten");
    check(!marked.wouldEat(Key::press(NamedKey::returnKey)), "eat: Return reaches the app after the commit");

    // A learned mode switch is part of the prediction.
    auto store = std::make_shared<SessionStore>();
    store->saved = {"learned.exe"};
    HostTestClient learnedClient;
    HostSession learned(std::make_shared<EmptyLexicon>(), store);
    check(learned.wouldEat(Key::typed(U's')) == false, "eat: before activation the app is unknown and eager");
    learned.activate("learned.exe", learnedClient);
    check(learned.wouldEat(Key::typed(U's')), "eat: a learned app predicts marked mode");
}

void runUtf16Tests() {
    auto document = [](std::u16string text, size_t caret, int* reads = nullptr) {
        return [text, caret, reads](size_t units) -> std::optional<std::u16string> {
            if (reads) ++*reads;
            const size_t from = caret > units ? caret - units : 0;
            return text.substr(from, caret - from);
        };
    };
    using utf16::Suffix;
    check(utf16::suffix(1, document(u"şahar", 5)) == Suffix{U"r", 1}, "utf16: one letter");
    check(utf16::suffix(2, document(u"a😀ş", 4)) == Suffix{U"😀ş", 3}, "utf16: a surrogate pair is one code point");
    check(utf16::suffix(5, document(u"ab", 2)) == Suffix{U"ab", 2}, "utf16: fewer code points near the start");
    check(utf16::suffix(2, document(u"xyzşab", 4)) == Suffix{U"zş", 2}, "utf16: reads before a mid-text caret");
    check(utf16::suffix(3, document(u"ab", 0)) == Suffix{U"", 0}, "utf16: nothing before the start");
    int reads = 0;
    check(utf16::suffix(0, document(u"abc", 3, &reads)) == Suffix{U"", 0} && reads == 0,
          "utf16: zero code points read nothing");
    // A window of 4 units starting inside the first pair: the lone low surrogate must not count.
    check(utf16::suffix(1, document(u"😀😀😀", 6)) == Suffix{U"😀", 2}, "utf16: a window starting inside a pair");
    check(!utf16::suffix(1, [](size_t) { return std::optional<std::u16string>(); }),
          "utf16: a failed read reports no text");
    check(
        !utf16::suffix(1, [](size_t units) { return std::optional<std::u16string>(std::u16string(units + 1, u'a')); }),
        "utf16: a read longer than asked reports no text");
    std::u16string zalgo = u"a" + std::u16string(utf16::maxWindow + 10, u'\x0301');
    check(utf16::suffix(1, document(zalgo, zalgo.size())) == Suffix{U"\x0301", 1},
          "utf16: a combining mark is its own code point");
}

void runCaretTests() {
    using Selection = CaretTracker::Selection;
    CaretTracker fresh;
    check(!fresh.sync(Selection{5, 0}) && fresh.location() == 5, "caret: the first report is a baseline");
    check(!fresh.sync(Selection{5, 0}), "caret: the same caret is no move");
    check(fresh.sync(Selection{2, 0}) && fresh.location() == 2, "caret: another caret is a move");
    check(fresh.sync(Selection{2, 3}) && !fresh.location(), "caret: a selection is a move and unknown");
    check(!fresh.sync(Selection{4, 0}) && fresh.location() == 4, "caret: nothing to compare after unknown");
    check(!fresh.sync(std::nullopt) && !fresh.location(), "caret: no report is unknown");

    CaretTracker typing;
    typing.sync(Selection{10, 0});
    typing.passed(Text(U"s"));
    typing.replace(1, U"ş");
    check(typing.location() == 11, "caret: s to ş keeps the caret");
    typing.passed(Text(U"😀"));
    check(typing.location() == 13, "caret: a passed emoji moves by its UTF-16 units");
    typing.replace(2, U"push");
    check(typing.location() == 15, "caret: a guard restore moves by the difference");
    typing.passed(std::nullopt);
    check(!typing.location(), "caret: a passed key with unknown effect forgets the caret");

    CaretTracker lagging;
    lagging.sync(Selection{10, 0});
    lagging.replace(2, U"ş");
    check(!lagging.sync(Selection{10, 0}) && lagging.location() == 9,
          "caret: a lagging report keeps the predicted caret");
    check(lagging.sync(Selection{4, 0}) && lagging.location() == 4,
          "caret: another report after a replacement is a move");

    CaretTracker marked;
    marked.sync(Selection{0, 0});
    marked.setMarked(U"s");
    check(marked.location() == 1 && marked.markedUnits() == 1, "caret: marked text ends at the caret");
    marked.insert(U"şö");
    check(marked.location() == 2 && marked.markedUnits() == 0, "caret: a commit replaces the marked text");
    marked.setMarked(U"o");
    marked.passed(Text(U"x"));
    check(!marked.location(), "caret: a key passed over marked text forgets the caret");
}

void runKeyMapperTests() {
    auto facts = [](unsigned vk, std::optional<char32_t> text, bool control = false, bool alt = false,
                    bool extended = false) {
        KeyFacts f;
        f.virtualKey = vk;
        f.text = text;
        f.control = control;
        f.alt = alt;
        f.extended = extended;
        return f;
    };
    check(keymapper::key(facts('S', U's')) == Key::typed(U's'), "keys: a letter");
    check(keymapper::key(facts('S', U'S')) == Key::typed(U'S'), "keys: Shift or Caps Lock letter");
    check(keymapper::key(facts(0xDE, U'\'')) == Key::typed(U'\''), "keys: the apostrophe key");
    check(keymapper::key(facts('S', U's', true, true)) == Key::typed(U's', true), "keys: AltGr+S is the option key");
    check(keymapper::key(facts(0xDE, U'"', true, true)) == Key::typed(U'"', true),
          "keys: AltGr+Shift+' is option quote");
    check(keymapper::key(facts('C', U'c', true)) == Key::shortcut(), "keys: Ctrl+C is a shortcut");
    check(keymapper::key(facts('F', U'f', false, true)) == Key::shortcut(), "keys: Alt+F is a shortcut");
    check(keymapper::key(facts(0x0D, std::nullopt)) == Key::press(NamedKey::returnKey), "keys: Return");
    check(keymapper::key(facts(0x0D, std::nullopt, false, false, true)) == Key::press(NamedKey::enter),
          "keys: numpad Enter");
    check(keymapper::key(facts(0x08, std::nullopt)) == Key::press(NamedKey::backspace), "keys: Backspace");
    check(keymapper::key(facts(0x08, std::nullopt, true)) == Key::shortcut(), "keys: Ctrl+Backspace is a shortcut");
    check(keymapper::key(facts(0x25, std::nullopt)) == Key::press(NamedKey::left), "keys: Left");
    check(keymapper::key(facts(0x2E, std::nullopt)) == Key::shortcut(), "keys: Delete is a shortcut");
    check(keymapper::key(facts(0x24, std::nullopt)) == Key::shortcut(), "keys: Home is a shortcut");
    check(!keymapper::key(facts(0x10, std::nullopt)), "keys: Shift alone is not ours");
    check(!keymapper::key(facts(0x14, std::nullopt)), "keys: Caps Lock is not ours");
    check(!keymapper::key(facts(0x74, std::nullopt)), "keys: F5 is not ours");
    check(!keymapper::key(facts(0xAD, std::nullopt)), "keys: a media key types nothing");
    check(!keymapper::key(facts('E', std::nullopt, true, true)), "keys: AltGr with no text is not ours");
    check(!keymapper::key(facts('A', U'\x01')), "keys: a control character is not ours");
}

}  // namespace

void runHostTests() {
    runSessionTests();
    runWouldEatTests();
    runUtf16Tests();
    runCaretTests();
    runKeyMapperTests();
}

}  // namespace xattot::test
