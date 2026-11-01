// Types each corpus line through the C++ engine and prints the text, caret marked with `|`,
// after every key and after the final word boundary, exactly as main.swift beside it does.
// Usage: replay <inputmethod/Resources> < corpus

#include <iostream>
#include <string>

#include "../Check.h"
#include "../FakeClient.h"

using namespace xattot;
using namespace xattot::test;

namespace {

std::string unescape(const std::string& s) {
    std::string out;
    bool escaped = false;
    for (char c : s) {
        if (escaped) {
            out.push_back(c == 'n' ? '\n' : c == 't' ? '\t' : c);
            escaped = false;
        } else if (c == '\\') {
            escaped = true;
        } else {
            out.push_back(c);
        }
    }
    return out;
}

std::string escape(const std::string& s) {
    std::string out;
    for (char c : s) {
        if (c == '\\')
            out += "\\\\";
        else if (c == '\n')
            out += "\\n";
        else if (c == '\t')
            out += "\\t";
        else
            out.push_back(c);
    }
    return out;
}

std::string notation(const Key& key) {
    switch (key.kind) {
    case Key::Kind::character: return (key.option ? "⌥" : "") + toUtf8(Text(1, key.character));
    case Key::Kind::shortcut: return "⌘";
    case Key::Kind::named:
        switch (key.named) {
        case NamedKey::backspace: return "⌫";
        case NamedKey::returnKey: return "↵";
        case NamedKey::tab: return "⇥";
        case NamedKey::escape: return "⎋";
        case NamedKey::left: return "←";
        case NamedKey::right: return "→";
        default: return "⌘";
        }
    }
    return "⌘";
}

std::string snapshot(const FakeClient& client) {
    return escape(toUtf8(client.text.substr(0, client.caret)) + "|" + toUtf8(client.text.substr(client.caret)));
}

std::vector<std::string> split(const std::string& s, char separator, size_t maxParts) {
    std::vector<std::string> parts;
    size_t start = 0;
    while (parts.size() + 1 < maxParts) {
        const size_t end = s.find(separator, start);
        if (end == std::string::npos) break;
        parts.push_back(s.substr(start, end - start));
        start = end + 1;
    }
    parts.push_back(s.substr(start));
    return parts;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2) return 2;
    const auto loaded = WordListLexicon::load(argv[1]);
    if (!loaded) {
        std::cerr << "bundled lexicon did not load\n";
        return 1;
    }
    const auto bundled = std::make_shared<WordListLexicon>(*loaded);
    const auto small =
        std::make_shared<WordListLexicon>(std::vector<Text>{U"push", U"change", U"shop", U"don't", U"video", U"chap",
                                                            U"chrome", U"log", U"chin", U"sham", U"show"},
                                          std::vector<Text>{U"çap", U"çin", U"şam"});
    const auto none = std::make_shared<EmptyLexicon>();

    std::string line;
    std::string output;
    while (std::getline(std::cin, line)) {
        const auto parts = split(line, '\t', 2);
        const auto config = split(parts[0], ',', 4);
        std::shared_ptr<const Lexicon> lexicon = config[1] == "small"     ? small
                                                 : config[1] == "bundled" ? bundled
                                                                          : nullptr;
        Engine engine(lexicon ? lexicon : none, config[0] == "marked" ? Mode::marked : Mode::eager);
        FakeClient client;
        client.stale = config[2] == "1";
        client.smartQuotes = config[3] == "1";
        output += line;
        for (const Key& key : keys(unescape(parts[1]))) {
            client.type(notation(key), engine);
            output += "\t" + snapshot(client);
        }
        client.finish(engine);
        output += "\t" + snapshot(client) + "\n";
    }
    std::cout << output;
    return failures == 0 ? 0 : 1;
}
