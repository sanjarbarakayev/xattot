#pragma once

#include <optional>

#include "../engine/Text.h"

namespace xattot {

// The focused text field as the session sees it. Lengths count code points before the caret;
// the TSF adapter maps them to the document's UTF-16 units.
class TextClient {
public:
    virtual ~TextClient() = default;
    // Up to `length` code points immediately before the caret, fewer near the start; nullopt when the
    // client exposes no text.
    virtual std::optional<Text> textBefore(size_t length) = 0;
    // Replaces the `length` code points immediately before the caret. False when the document refused
    // the write: TSF reports that, where IMK did not.
    virtual bool replace(size_t length, const Text& text) = 0;
    // Inserts at the caret, replacing the marked range if there is one.
    virtual void insert(const Text& text) = 0;
    // Sets the marked range (the composition) at the caret; an empty `text` clears it.
    virtual void setMarked(const Text& text) = 0;
    // Replaces the marked range (or inserts at the caret) and ends composition.
    virtual void commit(const Text& text) = 0;
};

}  // namespace xattot
