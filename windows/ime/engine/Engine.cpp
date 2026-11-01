#include "Engine.h"

#include "MarkedComposer.h"
#include "Rules.h"

namespace xattot {

Engine::Engine(std::shared_ptr<const Lexicon> lexicon, Mode mode) : mode_(mode), lexicon_(std::move(lexicon)) {}

Engine::Engine(const Engine& other)
    : mode_(other.mode_),
      lexicon_(other.lexicon_),
      word_(other.word_),
      lastReplacement_(other.lastReplacement_),
      composer_(other.composer_ ? std::make_unique<MarkedComposer>(*other.composer_) : nullptr),
      undo_(other.undo_),
      codeSpan_(other.codeSpan_) {}

Engine& Engine::operator=(const Engine& other) {
    if (this != &other) *this = Engine(other);
    return *this;
}

Engine::Engine(Engine&&) noexcept = default;
Engine& Engine::operator=(Engine&&) noexcept = default;
Engine::~Engine() = default;

Edits Engine::switchMode(Mode mode) {
    Edits edits = endWord();
    if (mode != mode_) {
        mode_ = mode;
        reset();
    }
    return edits;
}

void Engine::reset() {
    composer_.reset();
    word_ = Word();
    undo_ = Undo();
    codeSpan_.reset();
}

MarkedComposer& Engine::composer() {
    if (!composer_) composer_ = std::make_unique<MarkedComposer>(lexicon_);
    return *composer_;
}

Edits Engine::handle(const Key& key) {
    if (mode_ == Mode::marked) return composer().handle(key);
    undo_ = Undo();
    if (codeSpan_) return codeSpanKey(key);
    if (key.isCharacter(false) && isLetter(key.character)) return letter(key.character);
    if (key.isCharacter(false) && (key.character == U'\'' || key.character == U'`')) return mark(key.character);
    if (key.isCharacter(true)) {
        const auto typed = rules::optionLetter(key.character);
        if (!typed) return endWord() + Edits{Edit::pass()};
        return optionInsert(*typed);
    }
    if (key.is(NamedKey::backspace)) {
        backspace();
        return {Edit::pass()};
    }
    return endWord() + Edits{Edit::pass()};
}

Edits Engine::endWord() {
    if (mode_ == Mode::marked) return composer().endWord();
    undo_ = Undo();
    codeSpan_.reset();
    const Word word = std::move(word_);
    word_ = Word();
    if (!word.tracking) return {};
    const Text target = finalText(word);
    if (target == word.shown()) return {};
    undo_.kind = Undo::Kind::finishedWord;
    return {replacement(word, target)};
}

// A closing quote after o/g stays a plain mark (`'kino'`) whatever the English list says,
// and an English word gets its raw spelling back.
Text Engine::finalText(const Word& word) const {
    const Word closed = word.closingQuoteSplit();
    if (closed.shown() == closed.raw() || !isEnglishWord(closed) || isUzbekException(closed)) return closed.shown();
    return closed.raw();
}

// Also tries the word without its closing quote: `'video'` typed as `'videö`.
bool Engine::isEnglishWord(const Word& word) const {
    if (lexicon_->isEnglish(word.raw())) return true;
    const auto unquoted = word.unquoted(word.raw());
    return unquoted && lexicon_->isEnglish(*unquoted);
}

bool Engine::isUzbekException(const Word& word) const {
    if (lexicon_->isUzbekException(word.shown())) return true;
    const auto unquoted = word.unquoted(word.shown());
    return unquoted && lexicon_->isUzbekException(*unquoted);
}

Edits Engine::replacementFailed() {
    if (mode_ == Mode::marked) return {};
    Undo undo = std::move(undo_);
    undo_ = Undo();
    switch (undo.kind) {
    case Undo::Kind::finishedWord: return {};
    case Undo::Kind::word:
        word_ = std::move(undo.word);
        word_.tracking = false;
        return undo.fallback;
    case Undo::Kind::none: word_.tracking = false; return {};
    }
    return {};
}

// Replaces the whole word as shown, so a moved caret fails the check instead of editing other text.
Edit Engine::replacement(const Word& before, const Text& text) {
    lastReplacement_ = Replacement{before.shown(), before.staleView()};
    return Edit::replace(before.shown(), text);
}

// Inside a code span every key is typed as is, across spaces and punctuation.
Edits Engine::codeSpanKey(const Key& key) {
    if (key.isCharacter(false) && key.character == U'`') {
        codeSpan_.reset();
    } else if (key.kind == Key::Kind::character) {
        ++*codeSpan_;
    } else if (key.is(NamedKey::backspace)) {
        // Deleting the opening backtick ends the span.
        if (*codeSpan_ > 1) {
            --*codeSpan_;
        } else {
            codeSpan_.reset();
        }
    } else {
        codeSpan_.reset();
    }
    return {Edit::pass()};
}

// The app deletes one character; its piece goes with it. A word emptied this way starts over.
void Engine::backspace() {
    if (word_.pieces.empty()) {
        // The deleted character is the word's opening quote or lies before the word.
        word_ = Word();
        return;
    }
    word_.pieces.pop_back();
    if (word_.pieces.empty()) {
        const auto openedBy = word_.openedBy;
        word_ = Word();
        word_.openedBy = openedBy;
    } else if (word_.foreign && word_.pieces.size() <= word_.foreignAt) {
        word_.foreign = false;
    }
}

Edits Engine::letter(char32_t c) {
    if (word_.foreign || turnsForeign(c)) return foreignLetter(c);
    if (auto merged = completeDigraph(c)) return *merged;
    return append(Piece::plain(Text(1, c))) + Edits{Edit::pass()};
}

// Option keys type their character directly. The piece is the typed character itself
// (never an opener, never a foreign trigger), so nothing later joins or reverts it.
Edits Engine::optionInsert(const Text& typed) {
    const Piece piece = Piece::plain(typed);
    if (typed == Text(1, rules::tutuq)) {
        word_.pieces.push_back(piece);
        return {Edit::insert(typed)};
    }
    return append(piece) + Edits{Edit::insert(typed)};
}

// Adds the key's piece; a letter after a waiting apostrophe first turns it into tutuq.
Edits Engine::append(const Piece& piece) {
    if (!word_.tracking || word_.pieces.empty() || !isApostrophe(word_.pieces.back())) {
        word_.pieces.push_back(piece);
        return {};
    }
    const Word before = word_;
    Word restored = word_;
    restored.pieces.push_back(piece);
    undo_ = Undo{Undo::Kind::word, std::move(restored), {}};
    word_.pieces.back().shown = Text(1, rules::tutuq);
    const Edit edit = replacement(before, word_.shown());
    word_.pieces.push_back(piece);
    return {edit};
}

// In a foreign word letters just pass; the letter that turns it foreign first
// puts back the raw keys of everything converted so far.
Edits Engine::foreignLetter(char32_t c) {
    const Piece piece = Piece::plain(Text(1, c));
    Edits edits;
    if (!word_.foreign) {
        word_.foreign = true;
        word_.foreignAt = word_.pieces.size();
        if (word_.tracking && word_.shown() != word_.raw()) {
            Word restored = word_;
            restored.pieces.push_back(piece);
            undo_ = Undo{Undo::Kind::word, std::move(restored), {}};
            edits.push_back(replacement(word_, word_.raw()));
            // One piece per character: Backspace removes one piece per deleted character.
            std::vector<Piece> split;
            for (const Piece& old : word_.pieces) {
                for (char32_t k : old.raw) split.push_back(Piece::plain(Text(1, k)));
            }
            word_.pieces = std::move(split);
            word_.foreignAt = word_.pieces.size();
        }
    }
    word_.pieces.push_back(piece);
    edits.push_back(Edit::pass());
    return edits;
}

bool Engine::turnsForeign(char32_t c) const {
    if (rules::isForeignLetter(c)) return true;
    if (word_.pieces.empty() || word_.pieces.back().raw.size() != 1) return false;
    const char32_t opener = word_.pieces.back().raw.front();
    return rules::isForeignAfter(opener) && !rules::digraph(opener, c);
}

// `'` or a backtick: finishes o'/g' as a letter, waits as a possible tutuq after a letter,
// opens a code span when a backtick starts a word, and is a plain word boundary anywhere else.
Edits Engine::mark(char32_t c) {
    if (word_.foreign) return endWord() + Edits{Edit::pass()};
    if (auto merged = completeDigraph(c)) return *merged;
    if (c == U'\'' && !word_.pieces.empty()) {
        const Piece& last = word_.pieces.back();
        if (!last.raw.empty() && isLetter(last.raw.front()) && last.raw != Text(1, rules::tutuq)) {
            word_.pieces.push_back(Piece::plain(U"'"));
            return {Edit::pass()};
        }
    }
    const bool opens = word_.pieces.empty();
    Edits edits = endWord();
    if (opens && c == U'`') {
        codeSpan_ = 1;
    } else if (opens) {
        word_.openedBy = c;
    }
    edits.push_back(Edit::pass());
    return edits;
}

std::optional<Edits> Engine::completeDigraph(char32_t c) {
    if (!word_.tracking || word_.pieces.empty()) return std::nullopt;
    const Piece last = word_.pieces.back();
    if (last.raw.size() != 1) return std::nullopt;
    const auto joined = rules::digraph(last.raw.front(), c);
    if (!joined) return std::nullopt;
    const Word before = word_;
    Word restored = word_;
    restored.pieces.push_back(Piece::plain(Text(1, c)));
    undo_ = Undo{Undo::Kind::word, std::move(restored), {Edit::pass()}};
    word_.pieces.back() = Piece{last.raw + c, Text(1, *joined)};
    return Edits{replacement(before, word_.shown())};
}

bool Engine::isApostrophe(const Piece& piece) {
    return piece.raw == U"'" && piece.shown == U"'";
}

}  // namespace xattot
