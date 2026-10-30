#include "Lexicon.h"

#include <algorithm>
#include <fstream>
#include <sstream>

namespace xattot {

namespace {

std::optional<std::string> readFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) return std::nullopt;
    std::ostringstream contents;
    contents << file.rdbuf();
    return contents.str();
}

std::string key(const Text& word) {
    return toUtf8(lowercased(word));
}

// Lines of `utf8` without surrounding spaces, skipping empty and `#` lines.
template <typename Body>
void eachLine(std::string_view utf8, Body body) {
    size_t start = 0;
    while (start <= utf8.size()) {
        size_t end = utf8.find_first_of("\r\n", start);
        if (end == std::string_view::npos) end = utf8.size();
        size_t first = start, last = end;
        while (first < last && (utf8[first] == ' ' || utf8[first] == '\t')) ++first;
        while (last > first && (utf8[last - 1] == ' ' || utf8[last - 1] == '\t')) --last;
        if (first < last && utf8[first] != '#') body(utf8.substr(first, last - first));
        start = end + 1;
    }
}

}  // namespace

WordListLexicon::WordListLexicon(const std::vector<Text>& english, const std::vector<Text>& uzbekExceptions) {
    std::vector<std::string> englishKeys, exceptionKeys;
    for (const Text& word : english) englishKeys.push_back(key(word));
    for (const Text& word : uzbekExceptions) exceptionKeys.push_back(key(word));
    build(std::move(englishKeys), exceptionKeys);
}

// Parses straight into lowercase UTF-8 keys: no per-word UTF-32 copies of the 83,000 English words.
WordListLexicon WordListLexicon::parse(std::string_view englishUtf8, std::string_view exceptionsUtf8) {
    std::vector<std::string> englishKeys, exceptionKeys;
    eachLine(englishUtf8, [&](std::string_view word) { englishKeys.push_back(key(fromUtf8(word))); });
    eachLine(exceptionsUtf8, [&](std::string_view word) { exceptionKeys.push_back(key(fromUtf8(word))); });
    WordListLexicon lexicon;
    lexicon.build(std::move(englishKeys), exceptionKeys);
    return lexicon;
}

void WordListLexicon::build(std::vector<std::string> sorted, const std::vector<std::string>& exceptions) {
    std::sort(sorted.begin(), sorted.end());
    sorted.erase(std::unique(sorted.begin(), sorted.end()), sorted.end());
    size_t bytes = 0;
    for (const std::string& word : sorted) bytes += word.size();
    english_.reserve(bytes);
    starts_.reserve(sorted.size() + 1);
    for (const std::string& word : sorted) {
        starts_.push_back(static_cast<uint32_t>(english_.size()));
        english_ += word;
    }
    starts_.push_back(static_cast<uint32_t>(english_.size()));
    exceptions_.insert(exceptions.begin(), exceptions.end());
}

std::optional<WordListLexicon> WordListLexicon::load(const std::string& directory) {
    const auto english = readFile(directory + "/english-words.txt");
    const auto exceptions = readFile(directory + "/uzbek-exceptions.txt");
    if (!english || !exceptions) return std::nullopt;
    return parse(*english, *exceptions);
}

std::vector<Text> WordListLexicon::words(std::string_view utf8) {
    std::vector<Text> out;
    eachLine(utf8, [&](std::string_view word) { out.push_back(fromUtf8(word)); });
    return out;
}

bool WordListLexicon::isEnglish(const Text& word) const {
    const std::string k = key(word);
    const size_t i = lowerBound(k);
    return i + 1 < starts_.size() && english(i) == k;
}

bool WordListLexicon::hasEnglishPrefix(const Text& prefix) const {
    const std::string k = key(prefix);
    const size_t i = lowerBound(k);
    return i + 1 < starts_.size() && english(i).substr(0, k.size()) == k;
}

bool WordListLexicon::isUzbekException(const Text& word) const {
    return exceptions_.count(key(word)) > 0;
}

std::string_view WordListLexicon::english(size_t i) const {
    return std::string_view(english_).substr(starts_[i], starts_[i + 1] - starts_[i]);
}

size_t WordListLexicon::lowerBound(std::string_view key) const {
    size_t low = 0, high = starts_.size() - 1;
    while (low < high) {
        const size_t mid = (low + high) / 2;
        if (english(mid) < key) {
            low = mid + 1;
        } else {
            high = mid;
        }
    }
    return low;
}

}  // namespace xattot
