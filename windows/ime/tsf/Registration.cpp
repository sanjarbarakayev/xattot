#include "Registration.h"

#include <cwchar>
#include <string>

#include "Com.h"
#include "Globals.h"
#include "resource.h"

namespace xattot::tsf {

namespace {

// Keyboard TIP, Store apps, the taskbar's input indicator, apps that never initialize COM.
const GUID* const categories[] = {
    &GUID_TFCAT_TIP_KEYBOARD,
    &GUID_TFCAT_TIPCAP_IMMERSIVESUPPORT,
    &GUID_TFCAT_TIPCAP_SYSTRAYSUPPORT,
    &GUID_TFCAT_TIPCAP_UIELEMENTENABLED,
    &GUID_TFCAT_TIPCAP_COMLESS,
};

// Passed keys go through the US layout, the way the Mac input method forces ABC: the language's
// own default layout would put them through other dead keys or letters.
const HKL usLayout = reinterpret_cast<HKL>(static_cast<ULONG_PTR>(0x04090409));

std::wstring clsidKey() {
    wchar_t clsid[40] = {};
    StringFromGUID2(textServiceClsid, clsid, 40);
    return std::wstring(L"Software\\Classes\\CLSID\\") + clsid;
}

LSTATUS setString(HKEY key, const wchar_t* name, const std::wstring& value) {
    return RegSetValueExW(key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()),
                          static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

HRESULT registerClass(const std::wstring& path) {
    HKEY root = nullptr;
    if (RegCreateKeyExW(HKEY_LOCAL_MACHINE, clsidKey().c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &root, nullptr) != ERROR_SUCCESS) {
        return E_ACCESSDENIED;
    }
    HKEY server = nullptr;
    LSTATUS status = setString(root, nullptr, displayName);
    if (status == ERROR_SUCCESS) {
        status = RegCreateKeyExW(root, L"InprocServer32", 0, nullptr, 0, KEY_WRITE, nullptr, &server, nullptr);
    }
    if (status == ERROR_SUCCESS) status = setString(server, nullptr, path);
    if (status == ERROR_SUCCESS) status = setString(server, L"ThreadingModel", L"Apartment");
    if (server) RegCloseKey(server);
    RegCloseKey(root);
    return HRESULT_FROM_WIN32(status);
}

// regsvr32 initializes COM, but a direct caller may not have.
class ComScope {
public:
    ComScope() : hr_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
    ~ComScope() {
        if (SUCCEEDED(hr_)) CoUninitialize();
    }

private:
    HRESULT hr_;
};

}  // namespace

HRESULT registerServer() {
    wchar_t path[MAX_PATH] = {};
    const DWORD length = GetModuleFileNameW(module, path, MAX_PATH);
    if (length == 0 || length == MAX_PATH) return E_FAIL;

    ComScope com;
    HRESULT hr = registerClass(path);
    if (FAILED(hr)) return hr;

    Com<ITfInputProcessorProfileMgr> profiles;
    hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                          IID_ITfInputProcessorProfileMgr, reinterpret_cast<void**>(profiles.put()));
    if (FAILED(hr)) return hr;
    // A negative icon index names a resource ID.
    hr = profiles->RegisterProfile(textServiceClsid, language, profileGuid, displayName,
                                   static_cast<ULONG>(wcslen(displayName)), path, length,
                                   static_cast<ULONG>(-IDI_XATTOT), usLayout, 0, TRUE, 0);
    if (FAILED(hr)) return hr;

    Com<ITfCategoryMgr> categoryMgr;
    hr = CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER, IID_ITfCategoryMgr,
                          reinterpret_cast<void**>(categoryMgr.put()));
    if (FAILED(hr)) return hr;
    for (const GUID* category : categories) {
        hr = categoryMgr->RegisterCategory(textServiceClsid, *category, textServiceClsid);
        if (FAILED(hr)) return hr;
    }
    return S_OK;
}

// The x64 and x86 DLLs share one profile, so whichever unregisters second finds it gone:
// only the class key, which each view holds on its own, decides the result.
HRESULT unregisterServer() {
    ComScope com;
    Com<ITfCategoryMgr> categoryMgr;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_CategoryMgr, nullptr, CLSCTX_INPROC_SERVER, IID_ITfCategoryMgr,
                                   reinterpret_cast<void**>(categoryMgr.put())))) {
        for (const GUID* category : categories) categoryMgr->UnregisterCategory(textServiceClsid, *category, textServiceClsid);
    }
    Com<ITfInputProcessorProfileMgr> profiles;
    if (SUCCEEDED(CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_ITfInputProcessorProfileMgr, reinterpret_cast<void**>(profiles.put())))) {
        profiles->UnregisterProfile(textServiceClsid, language, profileGuid, 0);
    }
    const LSTATUS status = RegDeleteTreeW(HKEY_LOCAL_MACHINE, clsidKey().c_str());
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND ? S_OK : HRESULT_FROM_WIN32(status);
}

}  // namespace xattot::tsf
