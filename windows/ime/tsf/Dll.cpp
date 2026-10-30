#include <new>

#include "Globals.h"
#include "Registration.h"
#include "TextService.h"

namespace xattot::tsf {

HINSTANCE module = nullptr;
LONG objects = 0;

namespace {

class ClassFactory final : public IClassFactory {
public:
    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_INVALIDARG;
        if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IClassFactory)) {
            *ppv = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    // The factory is a static object; its references are the DLL's.
    STDMETHODIMP_(ULONG) AddRef() override {
        InterlockedIncrement(&objects);
        return 2;
    }

    STDMETHODIMP_(ULONG) Release() override {
        InterlockedDecrement(&objects);
        return 1;
    }

    STDMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
        if (!ppv) return E_INVALIDARG;
        *ppv = nullptr;
        if (outer) return CLASS_E_NOAGGREGATION;
        auto* service = new (std::nothrow) TextService();
        if (!service) return E_OUTOFMEMORY;
        const HRESULT hr = service->QueryInterface(riid, ppv);
        service->Release();
        return hr;
    }

    STDMETHODIMP LockServer(BOOL lock) override {
        if (lock) {
            InterlockedIncrement(&objects);
        } else {
            InterlockedDecrement(&objects);
        }
        return S_OK;
    }
};

ClassFactory factory;

}  // namespace

}  // namespace xattot::tsf

using namespace xattot::tsf;

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        module = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
    if (!ppv) return E_INVALIDARG;
    *ppv = nullptr;
    if (!IsEqualCLSID(clsid, textServiceClsid)) return CLASS_E_CLASSNOTAVAILABLE;
    return factory.QueryInterface(riid, ppv);
}

STDAPI DllCanUnloadNow() {
    return objects == 0 ? S_OK : S_FALSE;
}

STDAPI DllRegisterServer() {
    return registerServer();
}

STDAPI DllUnregisterServer() {
    return unregisterServer();
}
