#pragma once

#include <memory>
#include <optional>

#include "Edit.h"
#include "Key.h"
#include "Lexicon.h"
#include "Word.h"

namespace xattot {

class MarkedComposer;

// The C++ port of inputmethod/Sources/Engine/Engine.swift. Both engines replay the same
// parity data, and `make crosscheck` compares them key by key.
class Engine {
public:
    struct Replacement {
        Text expected;
        Text staleView;
    };

    explicit Engine(std::shared_ptr<const Lexicon> lexicon = std::make_shared<EmptyLexicon>(), Mode mode = Mode::eager);
    Engine(const Engine& other);
    Engine& operator=(const Engine& other);
    Engine(Engine&&) noexcept;
    Engine& operator=(Engine&&) noexcept;
    ~Engine();

    Mode mode() const { return mode_; }
    const Word& word() const { return word_; }
    // Set whenever a `replace` is emitted, for `AppModes::observe` after a failed check:
    // a guard replacement fails after its word is already reset.
    const std::optional<Replacement>& lastReplacement() const { return lastReplacement_; }

    // Ends the word, then changes the mode. Apply the returned edits before the next key.
    Edits switchMode(Mode mode);
    // Discards the current word and any marked state without emitting edits.
    void reset();

    // Eager-mode test hook: pieces in the current word, one per client character once a word
    // is reverted. Returns 0 in marked mode, where the word lives in the composer.
    size_t pieceCount() const { return word_.pieces.size(); }
    // True while a code span passes every key; the composer reads it from its inner engine.
    bool inCodeSpan() const { return codeSpan_.has_value(); }

    Edits handle(const Key& key);
    Edits endWord();
    // Called when the `replace` of the last edits failed its check.
    // The result stands in for that `replace`. Marked mode never emits one.
    Edits replacementFailed();

private:
    // How to recover if the `replace` in the last edits fails its check.
    struct Undo {
        enum class Kind {
            none,
            // Restore `word`, untracked, and apply `fallback` in place of the replacement.
            word,
            // The guard's word is already over: nothing to undo, the next word is untouched.
            finishedWord,
        };
        Kind kind = Kind::none;
        Word word;
        Edits fallback;
    };

    Mode mode_;
    std::shared_ptr<const Lexicon> lexicon_;
    Word word_;
    std::optional<Replacement> lastReplacement_;
    // Created on first use in marked mode; it runs an eager engine of its own.
    std::unique_ptr<MarkedComposer> composer_;
    Undo undo_;
    // Characters typed since a backtick opened a code span, that backtick included; nullopt outside a span.
    std::optional<int> codeSpan_;

    MarkedComposer& composer();
    Text finalText(const Word& word) const;
    bool isEnglishWord(const Word& word) const;
    bool isUzbekException(const Word& word) const;
    Edit replacement(const Word& before, const Text& text);
    Edits codeSpanKey(const Key& key);
    void backspace();
    Edits letter(char32_t c);
    Edits optionInsert(const Text& typed);
    Edits append(const Piece& piece);
    Edits foreignLetter(char32_t c);
    bool turnsForeign(char32_t c) const;
    Edits mark(char32_t c);
    std::optional<Edits> completeDigraph(char32_t c);
    static bool isApostrophe(const Piece& piece);
};

}  // namespace xattot
