#include "TsfClient.h"

#include <inputscope.h>

#include "Strings.h"

namespace xattot::tsf {

namespace {

bool isPasswordScope(InputScope scope) {
    return scope == IS_PASSWORD || scope == IS_NUMERIC_PASSWORD || scope == IS_NUMERIC_PIN ||
           scope == IS_ALPHANUMERIC_PIN || scope == IS_ALPHANUMERIC_PIN_SET;
}

}  // namespace

TsfClient::TsfClient(TfEditCookie cookie, ITfContext* context, ITfCompositionSink* sink, Composition& composition,
                     CaretTracker& caret)
    : cookie_(cookie), context_(context), sink_(sink), composition_(composition), caret_(caret) {
    // A composition left in another context is not this document's marked text.
    if (composition_.context.get() != context_) composition_ = Composition();
}

std::optional<CaretTracker::Selection> TsfClient::selection() {
    TF_SELECTION selection = {};
    ULONG fetched = 0;
    if (FAILED(context_->GetSelection(cookie_, TF_DEFAULT_SELECTION, 1, &selection, &fetched)) || fetched != 1) {
        return std::nullopt;
    }
    const auto range = Com<ITfRange>::attach(selection.range);
    const auto acp = range.as<ITfRangeACP>();
    LONG start = 0, length = 0;
    if (!acp || FAILED(acp->GetExtent(&start, &length))) return std::nullopt;
    return CaretTracker::Selection{start, length};
}

bool TsfClient::passesThrough() {
    TF_STATUS status = {};
    if (SUCCEEDED(context_->GetStatus(&status)) && (status.dwDynamicFlags & TF_SD_READONLY)) return true;

    TF_SELECTION selection = {};
    ULONG fetched = 0;
    if (FAILED(context_->GetSelection(cookie_, TF_DEFAULT_SELECTION, 1, &selection, &fetched)) || fetched != 1) return false;
    const auto range = Com<ITfRange>::attach(selection.range);
    Com<ITfProperty> property;
    if (FAILED(context_->GetProperty(GUID_PROP_INPUTSCOPE, property.put()))) return false;
    VARIANT value;
    VariantInit(&value);
    if (FAILED(property->GetValue(cookie_, range.get(), &value))) return false;
    bool password = false;
    if (value.vt == VT_UNKNOWN && value.punkVal) {
        Com<ITfInputScope> scope;
        value.punkVal->QueryInterface(IID_ITfInputScope, reinterpret_cast<void**>(scope.put()));
        InputScope* scopes = nullptr;
        UINT count = 0;
        if (scope && SUCCEEDED(scope->GetInputScopes(&scopes, &count))) {
            for (UINT i = 0; i < count; ++i) password = password || isPasswordScope(scopes[i]);
            CoTaskMemFree(scopes);
        }
    }
    VariantClear(&value);
    return password;
}

bool TsfClient::showsMarked() {
    if (!composition_.composition) return false;
    Com<ITfRange> range;
    BOOL empty = TRUE;
    return SUCCEEDED(composition_.composition->GetRange(range.put())) && SUCCEEDED(range->IsEmpty(cookie_, &empty)) && !empty;
}

Com<ITfRange> TsfClient::caretRange() {
    TF_SELECTION selection = {};
    ULONG fetched = 0;
    if (FAILED(context_->GetSelection(cookie_, TF_DEFAULT_SELECTION, 1, &selection, &fetched)) || fetched != 1) return {};
    auto range = Com<ITfRange>::attach(selection.range);
    BOOL empty = FALSE;
    if (FAILED(range->IsEmpty(cookie_, &empty)) || !empty) return {};
    return range;
}

std::optional<std::u16string> TsfClient::readBefore(ITfRange* caret, size_t units) {
    Com<ITfRange> range;
    if (FAILED(caret->Clone(range.put())) || FAILED(range->Collapse(cookie_, TF_ANCHOR_START))) return std::nullopt;
    LONG shifted = 0;
    if (FAILED(range->ShiftStart(cookie_, -static_cast<LONG>(units), &shifted, nullptr))) return std::nullopt;
    std::wstring buffer(units, L'\0');
    ULONG read = 0;
    if (FAILED(range->GetText(cookie_, 0, buffer.data(), static_cast<ULONG>(units), &read))) return std::nullopt;
    return std::u16string(buffer.begin(), buffer.begin() + read);
}

std::optional<utf16::Suffix> TsfClient::suffix(ITfRange* caret, size_t length) {
    return utf16::suffix(length, [&](size_t units) { return readBefore(caret, units); });
}

std::optional<Text> TsfClient::textBefore(size_t length) {
    const auto caret = caretRange();
    if (!caret) return std::nullopt;
    const auto found = suffix(caret.get(), length);
    if (!found) return std::nullopt;
    lastRead_ = std::make_pair(length, found->units);
    return found->text;
}

bool TsfClient::replace(size_t length, const Text& text) {
    const auto caret = caretRange();
    if (!caret) return false;
    size_t units = 0;
    if (lastRead_ && lastRead_->first == length) {
        units = lastRead_->second;
    } else if (const auto found = suffix(caret.get(), length)) {
        units = found->units;
    } else {
        return false;
    }
    lastRead_.reset();
    Com<ITfRange> range;
    if (FAILED(caret->Clone(range.put())) || FAILED(range->Collapse(cookie_, TF_ANCHOR_START))) return false;
    LONG shifted = 0;
    if (FAILED(range->ShiftStart(cookie_, -static_cast<LONG>(units), &shifted, nullptr)) || shifted != -static_cast<LONG>(units)) {
        return false;
    }
    const std::wstring wide = toWide(text);
    if (FAILED(range->SetText(cookie_, 0, wide.c_str(), static_cast<LONG>(wide.size())))) return false;
    moveCaretToEnd(range.get());
    caret_.replace(units, text);
    return true;
}

void TsfClient::insert(const Text& text) {
    if (composition_.composition) {
        commit(text);
    } else {
        insertAtSelection(text);
    }
}

void TsfClient::setMarked(const Text& text) {
    if (text.empty()) {
        if (composition_.composition) {
            Com<ITfRange> range;
            if (SUCCEEDED(composition_.composition->GetRange(range.put()))) range->SetText(cookie_, 0, L"", 0);
            endComposition();
        }
        caret_.setMarked(text);
        return;
    }
    if (!composition_.composition) {
        const auto insertion = Com<ITfContext>(context_).as<ITfInsertAtSelection>();
        const auto compositions = Com<ITfContext>(context_).as<ITfContextComposition>();
        Com<ITfRange> at;
        if (!insertion || !compositions ||
            FAILED(insertion->InsertTextAtSelection(cookie_, TF_IAS_QUERYONLY, nullptr, 0, at.put()))) {
            return;
        }
        // The app may refuse a composition: then nothing shows until the word is committed.
        if (FAILED(compositions->StartComposition(cookie_, at.get(), sink_, composition_.composition.put())) ||
            !composition_.composition) {
            composition_ = Composition();
            return;
        }
        composition_.context = context_;
    }
    Com<ITfRange> range;
    if (FAILED(composition_.composition->GetRange(range.put()))) return;
    const std::wstring wide = toWide(text);
    if (FAILED(range->SetText(cookie_, 0, wide.c_str(), static_cast<LONG>(wide.size())))) return;
    moveCaretToEnd(range.get());
    caret_.setMarked(text);
}

void TsfClient::commit(const Text& text) {
    if (!composition_.composition) {
        insertAtSelection(text);
        return;
    }
    Com<ITfRange> range;
    if (SUCCEEDED(composition_.composition->GetRange(range.put()))) {
        const std::wstring wide = toWide(text);
        if (SUCCEEDED(range->SetText(cookie_, 0, wide.c_str(), static_cast<LONG>(wide.size())))) moveCaretToEnd(range.get());
    }
    endComposition();
    caret_.insert(text);
}

void TsfClient::moveCaretToEnd(ITfRange* range) {
    Com<ITfRange> end;
    if (FAILED(range->Clone(end.put())) || FAILED(end->Collapse(cookie_, TF_ANCHOR_END))) return;
    TF_SELECTION selection = {};
    selection.range = end.get();
    selection.style.ase = TF_AE_NONE;
    selection.style.fInterimChar = FALSE;
    context_->SetSelection(cookie_, 1, &selection);
}

bool TsfClient::insertAtSelection(const Text& text) {
    const auto insertion = Com<ITfContext>(context_).as<ITfInsertAtSelection>();
    if (!insertion) return false;
    const std::wstring wide = toWide(text);
    Com<ITfRange> range;
    if (FAILED(insertion->InsertTextAtSelection(cookie_, 0, wide.c_str(), static_cast<LONG>(wide.size()), range.put()))) {
        return false;
    }
    moveCaretToEnd(range.get());
    caret_.insert(text);
    return true;
}

void TsfClient::endComposition() {
    if (composition_.composition) composition_.composition->EndComposition(cookie_);
    composition_ = Composition();
}

}  // namespace xattot::tsf
