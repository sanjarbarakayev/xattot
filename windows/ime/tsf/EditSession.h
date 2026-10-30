#pragma once

#include <functional>
#include <new>

#include "Com.h"
#include "Globals.h"

namespace xattot::tsf {

// Runs `body` under the document lock TSF grants. Every read and write of a document happens here.
class EditSession final : public ITfEditSession {
public:
    explicit EditSession(std::function<void(TfEditCookie)> body) : body_(std::move(body)) {
        InterlockedIncrement(&objects);
    }

    // Requests the lock; false when TSF granted none or the session failed.
    static bool run(ITfContext* context, TfClientId client, DWORD flags, std::function<void(TfEditCookie)> body) {
        Com<ITfEditSession> session(new (std::nothrow) EditSession(std::move(body)));
        if (!session) return false;
        session->Release();  // `new` started the count at one and Com added its own.
        HRESULT result = E_FAIL;
        const HRESULT hr = context->RequestEditSession(client, session.get(), flags, &result);
        return SUCCEEDED(hr) && SUCCEEDED(result);
    }

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_INVALIDARG;
        if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITfEditSession)) {
            *ppv = static_cast<ITfEditSession*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    STDMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&references_); }

    STDMETHODIMP_(ULONG) Release() override {
        const LONG count = InterlockedDecrement(&references_);
        if (count == 0) delete this;
        return count;
    }

    // No exception may unwind into the app.
    STDMETHODIMP DoEditSession(TfEditCookie cookie) override {
        try {
            body_(cookie);
            return S_OK;
        } catch (...) {
            return E_FAIL;
        }
    }

private:
    ~EditSession() { InterlockedDecrement(&objects); }

    LONG references_ = 1;
    std::function<void(TfEditCookie)> body_;
};

}  // namespace xattot::tsf
