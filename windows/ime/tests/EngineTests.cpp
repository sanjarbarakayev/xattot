#include <map>
#include <set>

#include "../engine/AppModes.h"
#include "../engine/Rules.h"
#include "Check.h"
#include "FakeClient.h"
#include "Json.h"
#include "Tests.h"

namespace xattot::test {

namespace {

std::shared_ptr<const Lexicon> small() {
    return std::make_shared<WordListLexicon>(
        std::vector<Text>{U"push", U"shop", U"chrome", U"don't", U"video", U"log", U"chin", U"chap", U"sham"},
        std::vector<Text>{U"çin", U"çap", U"şam"});
}

Options with(std::shared_ptr<const Lexicon> lexicon, Mode mode = Mode::eager, bool stale = false) {
    Options options;
    options.lexicon = std::move(lexicon);
    options.mode = mode;
    options.stale = stale;
    return options;
}

class MemoryStore final : public ModeStore {
public:
    std::set<std::string> apps;
    std::set<std::string> learnedMarkedApps() const override { return apps; }
    void learnMarkedApp(const std::string& app) override { apps.insert(app); }
    void forgetMarkedApp(const std::string& app) override { apps.erase(app); }
};

void runBehaviourTests() {
    // A few cases from each Swift suite, so the Windows CI catches a broken build of the port;
    // `make crosscheck` compares every Swift test input key by key on macOS.
    check(typed("shahar o'g'il choy") == "şahar öğil çoy", "digraphs");
    check(typed("SHahar CHoy O'zbek") == "Şahar Çoy Özbek", "capital openers");
    check(typed("ma'no san'at") == "maʼno sanʼat", "tutuq between letters");
    check(typed("show-off wish") == "show-off wish", "foreign revert");
    check(typed("cat") == "cat", "c without h is foreign");
    check(typed("pus⌫sh") == "puş", "Backspace forgets the piece, s joins again");
    check(typed("emas↵") == "emas\n", "Return reaches the app");
    check(typed("pus⌥h ⌥c⌥s⌥g⌥o") == "push çşğö", "option letters");
    check(typed("push shop", with(small())) == "push shop", "English guard");
    check(typed("chin chap sham", with(small())) == "çin çap şam", "Uzbek exception wins");
    check(typed("'video' `log`", with(small())) == "'video' `log`", "quotes and backticks");
    check(typed("shahar push", with(small(), Mode::eager, true)) == "şahar puş", "a stale client never corrupts");
    check(typed("push shahar", with(small(), Mode::marked, true)) == "push şahar", "marked mode with a stale client");
    check(typed("emas↵", with(nullptr, Mode::marked)) == "emas\n", "marked Return commits first");
    check(typed("`sh` sh") == "`sh` ş", "code span");

    Engine engine(small());
    for (char32_t c : Text(U"push")) engine.handle(Key::typed(c));
    check(engine.handle(Key::typed(U' ')) == Edits{Edit::replace(U"puş", U"push"), Edit::pass()},
          "the guard replacement comes before the boundary key");
    check(engine.replacementFailed().empty(), "a failed guard adds nothing");

    Engine marked(std::make_shared<EmptyLexicon>(), Mode::marked);
    check(marked.handle(Key::typed(U's')) == Edits{Edit::setMarked(U"s")}, "an opener is marked");
    check(marked.handle(Key::typed(U'h')) == Edits{Edit::commit(U"ş")}, "a finished digraph is committed");

    Engine copy = engine;
    copy.handle(Key::typed(U's'));
    check(engine.pieceCount() == 0 && copy.pieceCount() == 1, "a copied engine is independent");
}

void runRulesTests() {
    check(rules::digraph(U'S', U'H') == U'Ş', "capital digraph");
    check(!rules::digraph(U's', U'H'), "lowercase opener needs a lowercase h");
    check(rules::optionLetter(U'"') == Text(1, rules::tutuq), "Shift+option+' types tutuq");
    check(isLetter(rules::tutuq) && isLetter(U'ş') && !isLetter(U'\'') && !isLetter(U'7'), "letters");
    check(lowercased(U"ÇAP Ş Ğ Ö İ") == U"çap ş ğ ö i", "lowercase Uzbek capitals");
    check(fromUtf16(toUtf16(U"a😀ʼ")) == U"a😀ʼ" && utf16Length(U"a😀") == 3, "UTF-16 round trip");
    check(fromUtf16(u"\xDC00x") == U"\xFFFDx", "a lone surrogate decodes to U+FFFD");
}

void runAppModesTests() {
    auto store = std::make_shared<MemoryStore>();
    AppModes modes(store);
    check(modes.mode("code.exe") == Mode::marked, "VS Code is seeded");
    check(modes.mode("telegram.exe") == Mode::eager, "other apps start eager");
    modes.observe("telegram.exe", Text(U"pus"), U"puş", U"pus");
    check(modes.mode("telegram.exe") == Mode::marked && store->apps.count("telegram.exe"), "stale text is learned and stored");
    modes.forget("telegram.exe");
    check(modes.mode("telegram.exe") == Mode::eager && store->apps.empty(), "forget undoes it");
    for (int i = 0; i < 2; ++i) modes.observe("notepad.exe", std::nullopt, U"ş", U"s");
    check(modes.mode("notepad.exe") == Mode::eager, "two nils are not enough");
    modes.observe("notepad.exe", std::nullopt, U"ş", U"s");
    check(modes.mode("notepad.exe") == Mode::marked && store->apps.empty(), "three nils mark the app for the session only");
    modes.observe("slack.exe", Text(U"x"), U"ş", U"s");
    check(modes.mode("slack.exe") == Mode::eager, "unrelated text teaches nothing");
}

// Replays the free layout's simulator outputs through the engine, as ParityTests.swift does.
void runParityTests(const std::string& data) {
    const auto parityJson = readFile(data + "/Tests/parity.json");
    const auto divergencesJson = readFile(data + "/Tests/divergences.json");
    const auto cases = parityJson ? parseObjects(*parityJson) : std::nullopt;
    const auto divergences = divergencesJson ? parseObjects(*divergencesJson) : std::nullopt;
    const auto bundled = WordListLexicon::load(data + "/Resources");
    if (!cases || !divergences || !bundled) {
        check(false, "parity data and bundled lexicon load from " + data);
        return;
    }
    const auto lexicon = std::make_shared<WordListLexicon>(*bundled);
    std::map<std::string, JsonObject> byInput;
    for (const auto& d : *divergences) byInput[d.at("input")] = d;
    check(cases->size() >= 500, "parity data has the literals and the generated strings");

    size_t mismatches = 0;
    for (const auto& c : *cases) {
        const std::string& input = c.at("input");
        const auto d = byInput.find(input);
        const bool divergent = d != byInput.end();
        Options options;
        if (divergent && d->second.at("lexicon") == "bundled") options.lexicon = lexicon;
        const std::string expected = divergent ? d->second.at("engine") : c.at("output");
        const std::string actual = typed(input, options);
        if (actual != expected) {
            ++mismatches;
            check(false, "parity " + input + ": expected " + expected + ", got " + actual);
        }
    }
    check(mismatches == 0, std::to_string(cases->size()) + " parity cases match the free simulator or a documented divergence");

    // Every Uzbek exception must survive the bundled English list.
    const auto exceptions = readFile(data + "/Resources/uzbek-exceptions.txt");
    size_t lost = 0;
    for (const Text& entry : WordListLexicon::words(exceptions.value_or(""))) {
        Text raw;
        for (char32_t c : entry) {
            raw += c == U'ç' ? Text(U"ch") : c == U'ş' ? Text(U"sh") : c == U'ö' ? Text(U"o'") : c == U'ğ' ? Text(U"g'") : Text(1, c);
        }
        Options options;
        options.lexicon = lexicon;
        if (typed(toUtf8(raw), options) != toUtf8(entry)) ++lost;
    }
    check(exceptions && lost == 0, "every Uzbek exception stays Uzbek with the bundled list");
    check(lexicon->isEnglish(U"Change") && lexicon->hasEnglishPrefix(U"chan") && !lexicon->isEnglish(U"shahar"),
          "bundled English list lookups");
}

}  // namespace

void runEngineTests(const std::string& data) {
    runRulesTests();
    runBehaviourTests();
    runAppModesTests();
    runParityTests(data);
}

}  // namespace xattot::test
