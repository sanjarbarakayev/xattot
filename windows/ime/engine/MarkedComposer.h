#pragma once

#include <memory>
#include <optional>

#include "Edit.h"
#include "Key.h"
#include "Lexicon.h"

namespace xattot {

class Engine;
struct Word;
struct Piece;

// Marked-text mode for clients that keep reporting pre-replacement text (Monaco editors).
// An eager engine runs against a private copy of the current word; what it may still change
// stays marked (the composition), everything else is committed, so no `replace` reaches the client.
class MarkedComposer {
public:
    explicit MarkedComposer(std::shared_ptr<const Lexicon> lexicon);
    MarkedComposer(const MarkedComposer& other);
    ~MarkedComposer();

    Edits handle(const Key& key);
    // Lets the English guard decide the tail, then commits all of it.
    Edits endWord();

private:
    std::shared_ptr<const Lexicon> lexicon_;
    std::unique_ptr<Engine> inner_;
    // Text of this word the client already holds: passed keys and committed text. Never edited.
    Text committed_;
    // Text of this word the client shows as marked.
    Text tail_;

    Edits compose(const Key& key, std::optional<char32_t> typed);
    Edits backspace();
    void apply(const Edits& edits, std::optional<char32_t> typed);
    bool replaceInTail(const Text& expected, const Text& with);
    size_t undecidedLength() const;
    bool isEnglishPrefix(const Word& word) const;
    static bool isPending(const Piece& piece, const Word& word);
};

}  // namespace xattot
