#pragma once

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

#include "../host/HostSession.h"
#include "../host/Utf16Text.h"
#include "Com.h"
#include "Globals.h"
#include "TsfClient.h"

namespace xattot::tsf {

// The Özbekça (Xattot) text input processor: one per UI thread that activates it. It turns key
// events into engine keys and applies the engine's edits in TSF edit sessions, as Controller.swift
// does with IMK on the Mac.
class TextService final : public ITfTextInputProcessorEx,
                          public ITfThreadMgrEventSink,
                          public ITfKeyEventSink,
                          public ITfCompositionSink {
public:
    TextService();

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
    STDMETHODIMP_(ULONG) AddRef() override;
    STDMETHODIMP_(ULONG) Release() override;

    // ITfTextInputProcessor(Ex)
    STDMETHODIMP Activate(ITfThreadMgr* threadMgr, TfClientId client) override;
    STDMETHODIMP ActivateEx(ITfThreadMgr* threadMgr, TfClientId client, DWORD flags) override;
    STDMETHODIMP Deactivate() override;

    // ITfThreadMgrEventSink
    STDMETHODIMP OnInitDocumentMgr(ITfDocumentMgr*) override { return S_OK; }
    STDMETHODIMP OnUninitDocumentMgr(ITfDocumentMgr*) override { return S_OK; }
    STDMETHODIMP OnSetFocus(ITfDocumentMgr* focus, ITfDocumentMgr* previous) override;
    STDMETHODIMP OnPushContext(ITfContext*) override { return S_OK; }
    STDMETHODIMP OnPopContext(ITfContext*) override { return S_OK; }

    // ITfKeyEventSink
    STDMETHODIMP OnSetFocus(BOOL) override { return S_OK; }
    STDMETHODIMP OnTestKeyDown(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten) override;
    STDMETHODIMP OnKeyDown(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten) override;
    STDMETHODIMP OnTestKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    STDMETHODIMP OnKeyUp(ITfContext*, WPARAM, LPARAM, BOOL* eaten) override;
    STDMETHODIMP OnPreservedKey(ITfContext*, REFGUID, BOOL* eaten) override;

    // ITfCompositionSink
    STDMETHODIMP OnCompositionTerminated(TfEditCookie cookie, ITfComposition* composition) override;

private:
    ~TextService();

    LONG references_ = 1;
    Com<ITfThreadMgr> threadMgr_;
    TfClientId client_ = TF_CLIENTID_NULL;
    DWORD threadMgrCookie_ = TF_INVALID_COOKIE;
    bool keySinkAdvised_ = false;
    std::unique_ptr<HostSession> session_;
    // Where the host left the caret, carried between keys.
    CaretTracker caret_;
    Composition composition_;
    // The key event handled last and whether it was eaten, for repeated calls about the same event.
    struct KeyEvent {
        WPARAM wParam;
        LPARAM lParam;
        LONG time;
        bool operator==(const KeyEvent&) const = default;
    };
    std::optional<KeyEvent> handled_;
    bool handledEaten_ = false;
    // Bumped by every key and focus change: an edit session that runs later than asked checks it.
    uint64_t generation_ = 0;
    // Lowercase executable name: the text service lives inside the app's process.
    std::string app_;

    HRESULT handleKey(ITfContext* context, WPARAM wParam, LPARAM lParam, BOOL* eaten);
    // The key's edits, inside the edit session handleKey requested.
    void apply(TfEditCookie cookie, ITfContext* context, uint64_t at, const Key& key, bool predicted);
    std::optional<Key> key(WPARAM wParam, LPARAM lParam) const;
    bool keyboardDisabled(ITfContext* context) const;
    // Ends the word in `context` when TSF grants a lock now; otherwise the word is dropped.
    void endWordIn(ITfContext* context);
    TsfClient client(TfEditCookie cookie, ITfContext* context);
};

}  // namespace xattot::tsf
