#pragma once

#include <functional>
#include <optional>
#include <string>

#include "../engine/Text.h"

namespace xattot {

// Maps the session's code point counts to the UTF-16 units a TSF document indexes its text by.
namespace utf16 {

struct Suffix {
    Text text;
    // The UTF-16 length of `text` as the document stores it: the range to replace.
    size_t units = 0;
    bool operator==(const Suffix&) const = default;
};

// The most UTF-16 units read in one go; a longer run of code points reports no text.
inline constexpr size_t maxWindow = 1024;

// Reads up to `units` UTF-16 units ending at the caret; fewer only at the start of the document.
using Reader = std::function<std::optional<std::u16string>(size_t units)>;

// The last `count` code points before the caret (fewer near the start), read through `read`.
// nullopt when a read fails or comes back longer than asked, or the code points do not fit `maxWindow`.
std::optional<Suffix> suffix(size_t count, const Reader& read);

}  // namespace utf16

// Where the caret should be after the host's own edits and the keys it passed, in UTF-16 units.
// Unknown (nullopt) after a key whose effect the host cannot predict; the next report is then a baseline.
// The port of CaretTracker in inputmethod/Sources/Host/UTF16Text.swift.
class CaretTracker {
public:
    struct Selection {
        long start = 0;
        long length = 0;
        bool operator==(const Selection&) const = default;
    };

    std::optional<long> location() const { return location_; }
    size_t markedUnits() const { return markedUnits_; }

    // Takes the document's selection at the start of a key as the caret. Returns whether it moved
    // from where the host left it; a selection or no report (nullopt) leaves the caret unknown. No report
    // is no move: a document that never reports a caret would otherwise end every marked word.
    // A report still at the pre-edit caret is no move either, and the predicted caret stays: a real
    // click there fails the verified check instead of editing.
    bool sync(std::optional<Selection> reported);

    // Inserted or committed text, which replaces the marked text.
    void insert(const Text& text);
    void setMarked(const Text& text);
    void replace(size_t units, const Text& text);
    // A key the app handles itself: `typed` is the text it inserts, nullopt when that is unknown.
    void passed(const std::optional<Text>& typed);

private:
    std::optional<long> location_;
    // The marked text, which always ends at the caret.
    size_t markedUnits_ = 0;
    // The caret before the host's edits of the last key: a lagging document may still report it.
    std::optional<long> beforeEdits_;
};

}  // namespace xattot
