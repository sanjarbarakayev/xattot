#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_set>
#include <vector>

#include "Text.h"

namespace xattot {

class Lexicon {
public:
    virtual ~Lexicon() = default;
    virtual bool isEnglish(const Text& word) const = 0;
    virtual bool hasEnglishPrefix(const Text& prefix) const = 0;
    virtual bool isUzbekException(const Text& word) const = 0;
};

class EmptyLexicon final : public Lexicon {
public:
    bool isEnglish(const Text&) const override { return false; }
    bool hasEnglishPrefix(const Text&) const override { return false; }
    bool isUzbekException(const Text&) const override { return false; }
};

// Case-insensitive word lists: sorted English words (binary search) and a set of Uzbek exceptions.
// The text service loads into every process that takes keyboard focus, so the English words are
// one UTF-8 block with offsets, about 1 MB, instead of 83,000 separate strings.
class WordListLexicon final : public Lexicon {
public:
    WordListLexicon(const std::vector<Text>& english, const std::vector<Text>& uzbekExceptions);

    // The contents of `english-words.txt` and `uzbek-exceptions.txt`: one word per line, `#` lines are comments.
    static WordListLexicon parse(std::string_view englishUtf8, std::string_view exceptionsUtf8);
    // Reads both files from `directory`; nullopt when either is missing.
    static std::optional<WordListLexicon> load(const std::string& directory);
    static std::vector<Text> words(std::string_view utf8);

    bool isEnglish(const Text& word) const override;
    bool hasEnglishPrefix(const Text& prefix) const override;
    bool isUzbekException(const Text& word) const override;

private:
    WordListLexicon() = default;
    void build(std::vector<std::string> keys, const std::vector<std::string>& exceptions);

    // Lowercase UTF-8, sorted: byte order is code point order, so a prefix sorts right before its extensions.
    std::string english_;
    // Word i is english_[starts_[i], starts_[i + 1]); the last entry is english_.size().
    std::vector<uint32_t> starts_;
    std::unordered_set<std::string> exceptions_;

    std::string_view english(size_t i) const;
    // Index of the first English word that is not less than `key`.
    size_t lowerBound(std::string_view key) const;
};

}  // namespace xattot
