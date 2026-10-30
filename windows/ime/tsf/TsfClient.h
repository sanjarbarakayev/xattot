#pragma once

#include <optional>

#include "../host/TextClient.h"
#include "../host/Utf16Text.h"
#include "Com.h"
#include "Globals.h"

namespace xattot::tsf {

// The composition the text service owns in one context: the marked text.
struct Composition {
    Com<ITfComposition> composition;
    Com<ITfContext> context;
};

// `TextClient` over a TSF context for the length of one edit session. Reads and writes go
// through the live selection under the session's lock, and the caret tracker follows every edit.
class TsfClient final : public TextClient {
public:
    TsfClient(TfEditCookie cookie, ITfContext* context, ITfCompositionSink* sink, Composition& composition,
              CaretTracker& caret);

    // The selection as UTF-16 offsets; nullopt when the document has no ACP view or no selection.
    std::optional<CaretTracker::Selection> selection();
    // Read-only documents and password fields: the text service stays out of the way.
    bool passesThrough();
    // The composition's text is still in the document.
    bool showsMarked();

    std::optional<Text> textBefore(size_t length) override;
    bool replace(size_t length, const Text& text) override;
    void insert(const Text& text) override;
    void setMarked(const Text& text) override;
    void commit(const Text& text) override;

private:
    TfEditCookie cookie_;
    ITfContext* context_;
    ITfCompositionSink* sink_;
    Composition& composition_;
    CaretTracker& caret_;
    // The last verified read, whose exact UTF-16 length a replacement of the same code points takes.
    std::optional<std::pair<size_t, size_t>> lastRead_;

    // The empty selection at the caret; nullptr for a selection or none.
    Com<ITfRange> caretRange();
    std::optional<std::u16string> readBefore(ITfRange* caret, size_t units);
    std::optional<utf16::Suffix> suffix(ITfRange* caret, size_t length);
    void moveCaretToEnd(ITfRange* range);
    bool insertAtSelection(const Text& text);
    void endComposition();
};

}  // namespace xattot::tsf
