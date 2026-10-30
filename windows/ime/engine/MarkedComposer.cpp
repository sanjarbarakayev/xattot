#include "MarkedComposer.h"

#include <algorithm>

#include "Engine.h"
#include "Rules.h"

namespace xattot {

MarkedComposer::MarkedComposer(std::shared_ptr<const Lexicon> lexicon)
    : lexicon_(lexicon), inner_(std::make_unique<Engine>(std::move(lexicon), Mode::eager)) {}

MarkedComposer::MarkedComposer(const MarkedComposer& other)
    : lexicon_(other.lexicon_),
      inner_(std::make_unique<Engine>(*other.inner_)),
      committed_(other.committed_),
      tail_(other.tail_) {}

MarkedComposer::~MarkedComposer() = default;

Edits MarkedComposer::handle(const Key& key) {
    // A code span passes every key; the inner engine tracks where it ends.
    if (inner_->inCodeSpan()) {
        committed_.clear();
        return inner_->handle(key);
    }
    if (key.is(NamedKey::backspace)) return backspace();
    if (key.isCharacter(false)) {
        const char32_t c = key.character;
        if (isLetter(c) || c == U'\'' || c == U'`') return compose(key, c);
    }
    if (key.isCharacter(true) && rules::optionLetter(key.character)) return compose(key, std::nullopt);
    return endWord() + Edits{Edit::pass()};
}

Edits MarkedComposer::endWord() {
    apply(inner_->endWord(), std::nullopt);
    const Text tail = std::move(tail_);
    committed_.clear();
    tail_.clear();
    if (tail.empty()) return {};
    return {Edit::commit(tail)};
}

// `typed` is the key's character when the app could type it itself (no option).
Edits MarkedComposer::compose(const Key& key, std::optional<char32_t> typed) {
    const bool wasMarked = !tail_.empty();
    apply(inner_->handle(key), typed);
    const size_t keep = std::min(undecidedLength(), tail_.size());
    const Text settled = tail_.substr(0, tail_.size() - keep);
    tail_ = tail_.substr(tail_.size() - keep);
    committed_ += settled;
    if (!wasMarked && tail_.empty() && typed && settled == Text(1, *typed)) return {Edit::pass()};
    if (settled.empty()) return {Edit::setMarked(tail_)};
    Edits edits{Edit::commit(settled)};
    if (!tail_.empty()) edits.push_back(Edit::setMarked(tail_));
    return edits;
}

Edits MarkedComposer::backspace() {
    // One piece per client character, so the inner engine's own Backspace keeps it in step.
    inner_->handle(Key::press(NamedKey::backspace));
    if (tail_.empty()) {
        if (!committed_.empty()) committed_.pop_back();
        return {Edit::pass()};
    }
    tail_.pop_back();
    return {Edit::setMarked(tail_)};
}

// Plays the inner engine's edits on the buffer. A replacement that reaches into
// the committed text fails, and the engine's own failure path takes over.
void MarkedComposer::apply(const Edits& edits, std::optional<char32_t> typed) {
    for (const Edit& edit : edits) {
        switch (edit.kind) {
        case Edit::Kind::pass:
            if (typed) tail_.push_back(*typed);
            break;
        case Edit::Kind::insert:
        case Edit::Kind::commit:
            tail_ += edit.text;
            break;
        case Edit::Kind::setMarked:
            break;
        case Edit::Kind::replace:
            if (!replaceInTail(edit.expected, edit.text)) apply(inner_->replacementFailed(), typed);
            break;
        }
    }
}

// The guard replaces the whole word (`puş` -> `push`); only the part that differs must be in the tail.
bool MarkedComposer::replaceInTail(const Text& expected, const Text& with) {
    if (!hasSuffix(committed_ + tail_, expected)) return false;
    size_t shared = 0;
    while (shared < expected.size() && shared < with.size() && expected[shared] == with[shared]) ++shared;
    const size_t changed = expected.size() - shared;
    if (changed > tail_.size()) return false;
    tail_ = tail_.substr(0, tail_.size() - changed) + with.substr(shared);
    return true;
}

// Characters at the end of the tail that a later key may still change.
size_t MarkedComposer::undecidedLength() const {
    const Word& word = inner_->word();
    if (!word.tracking || word.pieces.empty()) return 0;
    const Piece& last = word.pieces.back();
    size_t length = 0;
    bool converted = false;
    for (auto piece = word.pieces.rbegin(); piece != word.pieces.rend(); ++piece) {
        if (length + piece->shown.size() > tail_.size()) break;
        length += piece->shown.size();
        converted = converted || piece->raw != piece->shown;
    }
    if (converted && isEnglishPrefix(word)) return length;
    if (isPending(last, word) || word.endsWithQuoteDigraph()) return std::min(last.shown.size(), tail_.size());
    return 0;
}

bool MarkedComposer::isEnglishPrefix(const Word& word) const {
    if (lexicon_->hasEnglishPrefix(word.raw())) return true;
    const auto unquoted = word.unquoted(word.raw());
    return unquoted && lexicon_->hasEnglishPrefix(*unquoted);
}

// An opener waiting for its second key, or an apostrophe that a letter would turn into tutuq.
bool MarkedComposer::isPending(const Piece& piece, const Word& word) {
    if (word.foreign || piece.raw != piece.shown || piece.raw.size() != 1) return false;
    const char32_t c = piece.raw.front();
    return rules::isOpener(c) || c == U'\'';
}

}  // namespace xattot
