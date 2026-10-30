#include "TextService.h"

#include <string_view>

#include "EditSession.h"
#include "RegistryModeStore.h"
#include "Strings.h"
#include "Trace.h"
#include "resource.h"
#include "../engine/Rules.h"
#include "../host/KeyMapper.h"

namespace xattot::tsf {

namespace {

std::optional<std::string_view> resource(int id) {
    HRSRC found = FindResourceW(module, MAKEINTRESOURCEW(id), MAKEINTRESOURCEW(10));  // RT_RCDATA
    if (!found) return std::nullopt;
    HGLOBAL loaded = LoadResource(module, found);
    const void* data = loaded ? LockResource(loaded) : nullptr;
    if (!data) return std::nullopt;
    return std::string_view(static_cast<const char*>(data), SizeofResource(module, found));
}

// Parsed once per process from the word lists linked into the DLL. Without them the English guard
// is off and everything else works.
std::shared_ptr<const Lexicon> sharedLexicon() {
    static const std::shared_ptr<const Lexicon> lexicon = []() -> std::shared_ptr<const Lexicon> {
        const auto english = resource(IDR_ENGLISH_WORDS);
        const auto exceptions = resource(IDR_UZBEK_EXCEPTIONS);
        if (!english || !exceptions) return std::make_shared<EmptyLexicon>();
        return std::make_shared<WordListLexicon>(WordListLexicon::parse(*english, *exceptions));
    }();
    return lexicon;
}

std::string appName() {
    std::wstring path(MAX_PATH, L'\0');
    const DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    path.resize(length);
    std::wstring name = path.substr(path.find_last_of(L"\\/") + 1);
    CharLowerBuffW(name.data(), static_cast<DWORD>(name.size()));
    return toUtf8(name);
}

// Activation needs a client, but no document is involved yet.
class NoText final : public TextClient {
public:
    std::optional<Text> textBefore(size_t) override { return std::nullopt; }
    bool replace(size_t, const Text&) override { return false; }
    void insert(const Text&) override {}
    void setMarked(const Text&) override {}
    void commit(const Text&) override {}
};

bool compartmentSet(ITfCompartmentMgr* compartments, REFGUID guid) {
    Com<ITfCompartment> compartment;
    if (FAILED(compartments->GetCompartment(guid, compartment.put()))) return false;
    VARIANT value;
    VariantInit(&value);
    const bool set = SUCCEEDED(compartment->GetValue(&value)) && value.vt == VT_I4 && value.lVal != 0;
    VariantClear(&value);
    return set;
}

}  // namespace

TextService::TextService() {
    InterlockedIncrement(&objects);
}

TextService::~TextService() {
    InterlockedDecrement(&objects);
}

STDMETHODIMP TextService::QueryInterface(REFIID riid, void** ppv) {
    if (!ppv) return E_INVALIDARG;
    *ppv = nullptr;
    if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfTextInputProcessor) ||
        IsEqualIID(riid, IID_ITfTextInputProcessorEx)) {
        *ppv = static_cast<ITfTextInputProcessorEx*>(this);
    } else if (IsEqualIID(riid, IID_ITfThreadMgrEventSink)) {
        *ppv = static_cast<ITfThreadMgrEventSink*>(this);
    } else if (IsEqualIID(riid, IID_ITfKeyEventSink)) {
        *ppv = static_cast<ITfKeyEventSink*>(this);
    } else if (IsEqualIID(riid, IID_ITfCompositionSink)) {
        *ppv = static_cast<ITfCompositionSink*>(this);
    } else {
        return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
}

STDMETHODIMP_(ULONG) TextService::AddRef() {
    return InterlockedIncrement(&references_);
}

STDMETHODIMP_(ULONG) TextService::Release() {
    const LONG count = InterlockedDecrement(&references_);
    if (count == 0) delete this;
    return count;
}

STDMETHODIMP TextService::Activate(ITfThreadMgr* threadMgr, TfClientId client) {
    return ActivateEx(threadMgr, client, 0);
}

// No exception may leave a TSF callback: it would unwind into the app.
STDMETHODIMP TextService::ActivateEx(ITfThreadMgr* threadMgr, TfClientId client, DWORD) {
    try {
        threadMgr_ = threadMgr;
        client_ = client;
        if (const auto source = threadMgr_.as<ITfSource>()) {
            const HRESULT hr = source->AdviseSink(IID_ITfThreadMgrEventSink, static_cast<ITfThreadMgrEventSink*>(this), &threadMgrCookie_);
            Trace::line("thread manager sink: 0x%08lx", static_cast<unsigned long>(hr));
        }
        if (const auto keystrokes = threadMgr_.as<ITfKeystrokeMgr>()) {
            const HRESULT hr = keystrokes->AdviseKeyEventSink(client_, static_cast<ITfKeyEventSink*>(this), TRUE);
            keySinkAdvised_ = SUCCEEDED(hr);
            Trace::line("key sink: 0x%08lx", static_cast<unsigned long>(hr));
        }
        app_ = appName();
        session_ = std::make_unique<HostSession>(sharedLexicon(), std::make_shared<RegistryModeStore>());
        NoText none;
        session_->activate(app_, none);
        Trace::line("activate %s, mode %s", app_.c_str(), session_->mode() == Mode::marked ? "marked" : "eager");
        return S_OK;
    } catch (...) {
        Deactivate();
        return E_FAIL;
    }
}

STDMETHODIMP TextService::Deactivate() {
    Trace::line("deactivate");
    try {
        if (session_ && threadMgr_) {
            Com<ITfDocumentMgr> focus;
            Com<ITfContext> context;
            if (SUCCEEDED(threadMgr_->GetFocus(focus.put())) && focus && SUCCEEDED(focus->GetTop(context.put())) && context) {
                endWordIn(context.get());
            }
        }
    } catch (...) {
    }
    if (threadMgr_) {
        if (const auto keystrokes = threadMgr_.as<ITfKeystrokeMgr>(); keystrokes && keySinkAdvised_) {
            keystrokes->UnadviseKeyEventSink(client_);
        }
        if (const auto source = threadMgr_.as<ITfSource>(); source && threadMgrCookie_ != TF_INVALID_COOKIE) {
            source->UnadviseSink(threadMgrCookie_);
        }
    }
    keySinkAdvised_ = false;
    threadMgrCookie_ = TF_INVALID_COOKIE;
    session_.reset();
    composition_ = Composition();
    caret_ = CaretTracker();
    threadMgr_.reset();
    client_ = TF_CLIENTID_NULL;
    return S_OK;
}

STDMETHODIMP TextService::OnSetFocus(ITfDocumentMgr* focus, ITfDocumentMgr* previous) {
    Trace::line("focus %p, previous %p", static_cast<void*>(focus), static_cast<void*>(previous));
    if (!session_) return S_OK;
    try {
        Com<ITfContext> context;
        if (previous && SUCCEEDED(previous->GetTop(context.put())) && context) endWordIn(context.get());
        ++generation_;
        handled_.reset();
        caret_ = CaretTracker();
        NoText none;
        session_->activate(app_, none);
    } catch (...) {
        session_->reset();
    }
    return S_OK;
}

STDMETHODIMP TextService::OnTestKeyDown(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten) {
    return handleKey(context, wParam, lParam, eaten);
}

STDMETHODIMP TextService::OnKeyDown(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten) {
    return handleKey(context, wParam, lParam, eaten);
}

// Apps call OnTestKeyDown several times for one key (Word), OnKeyDown only (some chat apps), or both,
// and TSF calls OnKeyDown only after an eaten test. So the first call handles the key and later calls
// for the same event get the same answer. The answer is the prediction: a failed check that would
// pass an eaten character types it here instead.
HRESULT TextService::handleKey(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten) {
    if (!eaten) return E_INVALIDARG;
    *eaten = FALSE;
    if (!session_ || !context) return S_OK;
    if (keyboardDisabled(context)) {
        Trace::line("key %#x: keyboard disabled", static_cast<unsigned>(wParam));
        return S_OK;
    }
    const KeyEvent event{wParam, lParam, GetMessageTime()};
    if (handled_ && *handled_ == event) {
        *eaten = handledEaten_ ? TRUE : FALSE;
        Trace::line("key %#x: repeated call, eaten %d", static_cast<unsigned>(wParam), *eaten);
        return S_OK;
    }
    try {
        const auto k = key(wParam, lParam);
        if (!k) {
            Trace::line("key %#x: not ours", static_cast<unsigned>(wParam));
            return S_OK;
        }
        const bool predicted = session_->wouldEat(*k);
        Trace::line("key %#x: char U+%04X option %d kind %d, predicted eaten %d", static_cast<unsigned>(wParam),
                    static_cast<unsigned>(k->character), k->option, static_cast<int>(k->kind), predicted);
        const uint64_t at = ++generation_;
        Com<TextService> keep(this);
        Com<ITfContext> target(context);
        const Key pressed = *k;
        // Synchronous whenever TSF allows it; a later run finds any newer key and drops the word instead.
        const bool ran = EditSession::run(context, client_, TF_ES_ASYNCDONTCARE | TF_ES_READWRITE,
                                          [keep, target, at, pressed, predicted](TfEditCookie cookie) {
                                              keep->apply(cookie, target.get(), at, pressed, predicted);
                                          });
        Trace::line("  edit session %s", ran ? "granted" : "refused");
        if (!ran) {
            // No lock: the app types the key and the word starts over, editing nothing.
            session_->reset();
            caret_ = CaretTracker();
            return S_OK;
        }
        handled_ = event;
        handledEaten_ = predicted;
        *eaten = predicted ? TRUE : FALSE;
    } catch (...) {
        session_->reset();
        caret_ = CaretTracker();
    }
    return S_OK;
}

void TextService::apply(TfEditCookie cookie, ITfContext* context, uint64_t at, const Key& key, bool predicted) {
    if (!session_) return;
    if (generation_ != at) {
        Trace::line("  late edit session: word dropped");
        session_->reset();
        return;
    }
    TsfClient document = client(cookie, context);
    if (document.passesThrough()) {
        Trace::line("  read-only or password field: passed through");
        session_->settle(document, document.showsMarked());
        caret_ = CaretTracker();
        // The key was already answered as eaten, so it is typed here, unconverted for a plain key.
        if (predicted && key.kind == Key::Kind::character) {
            document.insert(key.option ? rules::optionLetter(key.character).value_or(Text()) : Text(1, key.character));
        }
        return;
    }
    if (caret_.sync(document.selection())) {
        Trace::line("  caret moved: word settled");
        session_->settle(document, document.showsMarked());
        caret_.sync(document.selection());
    }
    const bool consumed = session_->handle(key, document);
    Trace::line("  handled: consumed %d, mode %s", consumed, session_->mode() == Mode::marked ? "marked" : "eager");
    const bool plain = key.isCharacter(false);
    if (!consumed && predicted && plain) {
        document.insert(Text(1, key.character));
    } else if (!consumed) {
        // A passed character is typed through the base layout; any other key's effect is unknown.
        caret_.passed(plain ? std::optional<Text>(Text(1, key.character)) : std::nullopt);
    }
}

STDMETHODIMP TextService::OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) {
    if (eaten) *eaten = FALSE;
    return S_OK;
}

STDMETHODIMP TextService::OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) {
    if (eaten) *eaten = FALSE;
    return S_OK;
}

STDMETHODIMP TextService::OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) {
    if (eaten) *eaten = FALSE;
    return S_OK;
}

// The app ended the marked text itself (a click, a focus change): it keeps that text as typed.
STDMETHODIMP TextService::OnCompositionTerminated(TfEditCookie, ITfComposition* composition) {
    if (composition_.composition.get() == composition) composition_ = Composition();
    if (session_) session_->reset();
    caret_ = CaretTracker();
    return S_OK;
}

std::optional<Key> TextService::key(WPARAM wParam, LPARAM lParam) const {
    KeyFacts facts;
    facts.virtualKey = static_cast<unsigned>(wParam);
    facts.extended = ((lParam >> 24) & 1) != 0;
    facts.control = GetKeyState(VK_CONTROL) < 0;
    facts.alt = GetKeyState(VK_MENU) < 0;
    // Shift and Caps Lock only: the text the key types without Ctrl or Alt.
    BYTE state[256] = {};
    if (GetKeyState(VK_SHIFT) < 0) state[VK_SHIFT] = 0x80;
    if (GetKeyState(VK_CAPITAL) & 1) state[VK_CAPITAL] = 0x01;
    wchar_t typed[4] = {};
    const UINT scanCode = static_cast<UINT>((lParam >> 16) & 0xFF);
    // Flag 4 leaves the kernel's dead-key state alone, so the app still sees the key as typed.
    const int count = ToUnicodeEx(facts.virtualKey, scanCode, state, typed, 4, 0x4, GetKeyboardLayout(0));
    if (count == 1) {
        facts.text = static_cast<char32_t>(typed[0]);
    } else if (count == 2 && IS_HIGH_SURROGATE(typed[0]) && IS_LOW_SURROGATE(typed[1])) {
        facts.text = fromUtf16(std::u16string{static_cast<char16_t>(typed[0]), static_cast<char16_t>(typed[1])}).front();
    }
    return keymapper::key(facts);
}

// Set for contexts that take no keyboard input or have no text, such as some password boxes.
bool TextService::keyboardDisabled(ITfContext* context) const {
    const auto compartments = Com<ITfContext>(context).as<ITfCompartmentMgr>();
    return compartments && (compartmentSet(compartments.get(), GUID_COMPARTMENT_KEYBOARD_DISABLED) ||
                            compartmentSet(compartments.get(), GUID_COMPARTMENT_EMPTYCONTEXT));
}

void TextService::endWordIn(ITfContext* context) {
    if (!session_) return;
    // Runs now when TSF allows it; a session that runs later finds the word gone and does nothing.
    const uint64_t at = generation_;
    Com<TextService> keep(this);
    Com<ITfContext> target(context);
    EditSession::run(context, client_, TF_ES_ASYNCDONTCARE | TF_ES_READWRITE, [keep, target, at](TfEditCookie cookie) {
        TextService& self = *keep.get();
        if (!self.session_ || self.generation_ != at) return;
        TsfClient document = self.client(cookie, target.get());
        self.session_->endWord(document, document.showsMarked());
    });
}

TsfClient TextService::client(TfEditCookie cookie, ITfContext* context) {
    return TsfClient(cookie, context, static_cast<ITfCompositionSink*>(this), composition_, caret_);
}

}  // namespace xattot::tsf
