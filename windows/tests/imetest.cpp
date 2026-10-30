// Types through the installed Özbekça (Xattot) input method the way an app does: a TSF thread manager,
// a document behind a minimal ITextStoreACP, and keys sent through ITfKeystrokeMgr. Keys the input
// method does not eat are typed into the document by this program, as the app would type them.
// Usage: imetest [--marked]. --marked stores this program as a learned marked-text app first.

#include <windows.h>

#include <msctf.h>
#include <textstor.h>

#include <cstdio>
#include <deque>
#include <fstream>
#include <iostream>
#include <string>

namespace {

const CLSID textService = {0xfd47e00c, 0x1dd3, 0x4169, {0xb4, 0x02, 0xbe, 0x4f, 0x14, 0x47, 0x3e, 0xee}};
const GUID profile = {0x59e8b67c, 0x4644, 0x47c6, {0x81, 0xce, 0xc0, 0x24, 0x9d, 0xd6, 0x69, 0xfa}};
const LANGID uzbekLatin = MAKELANGID(LANG_UZBEK, SUBLANG_UZBEK_LATIN);

std::string utf8(const std::wstring& text) {
    std::string out(WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), static_cast<int>(out.size()), nullptr, nullptr);
    return out;
}

// Line breaks shown as ↵, so a case stays on one line of the log.
std::string shown(const std::wstring& text) {
    std::wstring out;
    for (wchar_t c : text) out += c == L'\n' ? std::wstring(L"↵") : std::wstring(1, c);
    return utf8(out);
}

class TextStore final : public ITextStoreACP {
public:
    std::wstring text;
    LONG selStart = 0;
    LONG selEnd = 0;

    // IUnknown
    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_ITextStoreACP)) {
            *ppv = static_cast<ITextStoreACP*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }
    STDMETHODIMP_(ULONG) AddRef() override { return ++references_; }
    STDMETHODIMP_(ULONG) Release() override {
        const ULONG count = --references_;
        if (count == 0) delete this;
        return count;
    }

    STDMETHODIMP AdviseSink(REFIID riid, IUnknown* unknown, DWORD) override {
        if (!IsEqualIID(riid, IID_ITextStoreACPSink)) return E_INVALIDARG;
        if (sink_) sink_->Release();
        return unknown->QueryInterface(IID_ITextStoreACPSink, reinterpret_cast<void**>(&sink_));
    }
    STDMETHODIMP UnadviseSink(IUnknown*) override {
        if (sink_) sink_->Release();
        sink_ = nullptr;
        return S_OK;
    }

    // Grants a lock at once when none is held; queues an async request made under a lock.
    STDMETHODIMP RequestLock(DWORD flags, HRESULT* result) override {
        if (!sink_) return E_UNEXPECTED;
        if (lock_) {
            if (flags & TS_LF_SYNC) {
                *result = TS_E_SYNCHRONOUS;
                return S_OK;
            }
            queued_.push_back(flags & TS_LF_READWRITE);
            *result = TS_S_ASYNC;
            return S_OK;
        }
        lock_ = flags & TS_LF_READWRITE;
        *result = sink_->OnLockGranted(lock_);
        lock_ = 0;
        while (!queued_.empty()) {
            lock_ = queued_.front();
            queued_.pop_front();
            sink_->OnLockGranted(lock_);
            lock_ = 0;
        }
        return S_OK;
    }

    STDMETHODIMP GetStatus(TS_STATUS* status) override {
        status->dwDynamicFlags = 0;
        status->dwStaticFlags = TS_SS_NOHIDDENTEXT;
        return S_OK;
    }
    STDMETHODIMP QueryInsert(LONG start, LONG end, ULONG, LONG* resultStart, LONG* resultEnd) override {
        *resultStart = start;
        *resultEnd = end;
        return S_OK;
    }
    STDMETHODIMP GetSelection(ULONG, ULONG count, TS_SELECTION_ACP* selection, ULONG* fetched) override {
        if (count == 0) {
            *fetched = 0;
            return S_OK;
        }
        selection[0].acpStart = selStart;
        selection[0].acpEnd = selEnd;
        selection[0].style.ase = TS_AE_END;
        selection[0].style.fInterimChar = FALSE;
        *fetched = 1;
        return S_OK;
    }
    STDMETHODIMP SetSelection(ULONG count, const TS_SELECTION_ACP* selection) override {
        if (count > 0) {
            selStart = selection[0].acpStart;
            selEnd = selection[0].acpEnd;
        }
        return S_OK;
    }
    STDMETHODIMP GetText(LONG start, LONG end, WCHAR* plain, ULONG plainRequested, ULONG* plainReturned,
                         TS_RUNINFO* runs, ULONG runsRequested, ULONG* runsReturned, LONG* next) override {
        const LONG length = static_cast<LONG>(text.size());
        if (end < 0 || end > length) end = length;
        if (start < 0 || start > end) return TS_E_INVALIDPOS;
        const ULONG count = (std::min)(plainRequested, static_cast<ULONG>(end - start));
        if (plain) text.copy(plain, count, start);
        *plainReturned = plain ? count : 0;
        *runsReturned = 0;
        if (runsRequested > 0 && runs) {
            runs[0].uCount = count;
            runs[0].type = TS_RT_PLAIN;
            *runsReturned = 1;
        }
        *next = start + static_cast<LONG>(count);
        return S_OK;
    }
    STDMETHODIMP SetText(DWORD, LONG start, LONG end, const WCHAR* replacement, ULONG count, TS_TEXTCHANGE* change) override {
        if (!(lock_ & TS_LF_READWRITE)) return TS_E_NOLOCK;
        if (start < 0 || end < start || end > static_cast<LONG>(text.size())) return TS_E_INVALIDPOS;
        text.replace(start, end - start, replacement, count);
        const LONG newEnd = start + static_cast<LONG>(count);
        shift(start, end, newEnd);
        *change = {start, end, newEnd};
        return S_OK;
    }
    STDMETHODIMP GetFormattedText(LONG, LONG, IDataObject**) override { return E_NOTIMPL; }
    STDMETHODIMP GetEmbedded(LONG, REFGUID, REFIID, IUnknown**) override { return E_NOTIMPL; }
    STDMETHODIMP QueryInsertEmbedded(const GUID*, const FORMATETC*, BOOL* insertable) override {
        *insertable = FALSE;
        return S_OK;
    }
    STDMETHODIMP InsertEmbedded(DWORD, LONG, LONG, IDataObject*, TS_TEXTCHANGE*) override { return E_NOTIMPL; }
    STDMETHODIMP InsertTextAtSelection(DWORD flags, const WCHAR* inserted, ULONG count, LONG* start, LONG* end,
                                       TS_TEXTCHANGE* change) override {
        if (flags & TS_IAS_QUERYONLY) {
            *start = selStart;
            *end = selEnd;
            return S_OK;
        }
        if (!(lock_ & TS_LF_READWRITE)) return TS_E_NOLOCK;
        const LONG from = selStart, to = selEnd;
        text.replace(from, to - from, inserted, count);
        const LONG newEnd = from + static_cast<LONG>(count);
        selStart = selEnd = newEnd;
        if (start) *start = from;
        if (end) *end = newEnd;
        if (change) *change = {from, to, newEnd};
        return S_OK;
    }
    STDMETHODIMP InsertEmbeddedAtSelection(DWORD, IDataObject*, LONG*, LONG*, TS_TEXTCHANGE*) override { return E_NOTIMPL; }
    STDMETHODIMP RequestSupportedAttrs(DWORD, ULONG, const TS_ATTRID*) override { return S_OK; }
    STDMETHODIMP RequestAttrsAtPosition(LONG, ULONG, const TS_ATTRID*, DWORD) override { return S_OK; }
    STDMETHODIMP RequestAttrsTransitioningAtPosition(LONG, ULONG, const TS_ATTRID*, DWORD) override { return S_OK; }
    STDMETHODIMP FindNextAttrTransition(LONG, LONG halt, ULONG, const TS_ATTRID*, DWORD, LONG* next, BOOL* found,
                                        LONG* offset) override {
        *next = halt;
        *found = FALSE;
        *offset = 0;
        return S_OK;
    }
    STDMETHODIMP RetrieveRequestedAttrs(ULONG, TS_ATTRVAL*, ULONG* fetched) override {
        *fetched = 0;
        return S_OK;
    }
    STDMETHODIMP GetEndACP(LONG* end) override {
        *end = static_cast<LONG>(text.size());
        return S_OK;
    }
    STDMETHODIMP GetActiveView(TsViewCookie* view) override {
        *view = 1;
        return S_OK;
    }
    STDMETHODIMP GetACPFromPoint(TsViewCookie, const POINT*, DWORD, LONG*) override { return E_NOTIMPL; }
    STDMETHODIMP GetTextExt(TsViewCookie, LONG, LONG, RECT* rect, BOOL* clipped) override {
        *rect = {};
        *clipped = FALSE;
        return S_OK;
    }
    STDMETHODIMP GetScreenExt(TsViewCookie, RECT* rect) override {
        *rect = {};
        return S_OK;
    }
    STDMETHODIMP GetWnd(TsViewCookie, HWND* window) override {
        *window = nullptr;
        return S_OK;
    }

    // What the app does with a key the input method passed: types it and tells TSF.
    void typeItself(UINT vk, wchar_t typed) {
        LONG from = selStart, to = selEnd;
        std::wstring inserted;
        if (vk == VK_BACK) {
            if (from == to && from > 0) --from;
        } else if (vk == VK_RETURN) {
            inserted = L"\n";
        } else if (typed) {
            inserted = std::wstring(1, typed);
        } else {
            return;
        }
        text.replace(from, to - from, inserted);
        selStart = selEnd = from + static_cast<LONG>(inserted.size());
        TS_TEXTCHANGE change = {from, to, selEnd};
        if (sink_) {
            sink_->OnTextChange(0, &change);
            sink_->OnSelectionChange();
        }
    }

private:
    ~TextStore() = default;

    void shift(LONG start, LONG oldEnd, LONG newEnd) {
        auto move = [&](LONG& position) {
            if (position >= oldEnd) position += newEnd - oldEnd;
            else if (position > start) position = newEnd;
        };
        move(selStart);
        move(selEnd);
    }

    ULONG references_ = 1;
    ITextStoreACPSink* sink_ = nullptr;
    DWORD lock_ = 0;
    std::deque<DWORD> queued_;
};

struct Case {
    const wchar_t* keys;
    const wchar_t* expected;
};

// ↵ is Return and ⌫ Backspace; every other character is typed with the US layout key that makes it.
const Case cases[] = {
    {L"shahar o'g'il ", L"şahar öğil "},
    {L"SHahar CHoy ", L"Şahar Çoy "},
    {L"ma'no san'at ", L"maʼno sanʼat "},
    {L"push shop chrome ", L"push shop chrome "},
    {L"bosh chin ", L"boş çin "},
    {L"show-off ", L"show-off "},
    {L"pus⌫sh ", L"puş "},
    {L"emas↵", L"emas\n"},
    {L"'video' ", L"'video' "},
};

class Typist {
public:
    Typist(ITfThreadMgr* threadMgr, TfClientId client, HKL layout) : threadMgr_(threadMgr), client_(client), layout_(layout) {
        threadMgr_->QueryInterface(IID_ITfKeystrokeMgr, reinterpret_cast<void**>(&keystrokes_));
    }
    ~Typist() {
        if (keystrokes_) keystrokes_->Release();
    }

    // A fresh focused document per case: the focus change also ends the previous word.
    bool run(const Case& c) {
        TextStore* store = new TextStore();
        ITfDocumentMgr* document = nullptr;
        ITfContext* context = nullptr;
        TfEditCookie cookie = 0;
        bool ok = SUCCEEDED(threadMgr_->CreateDocumentMgr(&document)) &&
                  SUCCEEDED(document->CreateContext(client_, 0, static_cast<ITextStoreACP*>(store), &context, &cookie)) &&
                  SUCCEEDED(document->Push(context)) && SUCCEEDED(threadMgr_->SetFocus(document));
        if (!ok) {
            std::printf("FAIL could not focus a document\n");
            return false;
        }
        for (const wchar_t* k = c.keys; *k; ++k) press(*store, *k);
        // The word ends when focus leaves, as when the user clicks elsewhere.
        ITfDocumentMgr* other = nullptr;
        threadMgr_->CreateDocumentMgr(&other);
        threadMgr_->SetFocus(other);
        const bool passed = store->text == c.expected;
        std::printf("%s %s -> %s\n", passed ? "ok  " : "FAIL", shown(c.keys).c_str(), shown(store->text).c_str());
        if (!passed) std::printf("     expected %s\n", shown(c.expected).c_str());
        document->Pop(TF_POPF_ALL);
        context->Release();
        document->Release();
        other->Release();
        store->Release();
        return passed;
    }

private:
    ITfThreadMgr* threadMgr_;
    TfClientId client_;
    HKL layout_;
    ITfKeystrokeMgr* keystrokes_ = nullptr;

    void press(TextStore& store, wchar_t c) {
        UINT vk = 0;
        bool shift = false;
        wchar_t typed = 0;
        if (c == L'↵') {
            vk = VK_RETURN;
        } else if (c == L'⌫') {
            vk = VK_BACK;
        } else {
            const SHORT scan = VkKeyScanExW(c, layout_);
            vk = LOBYTE(scan);
            shift = (HIBYTE(scan) & 1) != 0;
            typed = c;
        }
        BYTE state[256] = {};
        if (shift) state[VK_SHIFT] = 0x80;
        SetKeyboardState(state);
        const LPARAM lParam = 1 | (static_cast<LPARAM>(MapVirtualKeyExW(vk, MAPVK_VK_TO_VSC, layout_)) << 16);
        // A new message time per key, as real key events have: the input method tells events apart by it.
        const DWORD before = GetTickCount();
        while (GetTickCount() == before) Sleep(1);
        PostThreadMessageW(GetCurrentThreadId(), WM_NULL, 0, 0);
        MSG message;
        GetMessageW(&message, nullptr, 0, 0);
        BOOL eaten = FALSE;
        // The order apps that drive TSF use: test first, the real call only for an eaten key.
        if (SUCCEEDED(keystrokes_->TestKeyDown(vk, lParam, &eaten)) && eaten) keystrokes_->KeyDown(vk, lParam, &eaten);
        if (!eaten) store.typeItself(vk, typed);
        BOOL up = FALSE;
        if (SUCCEEDED(keystrokes_->TestKeyUp(vk, lParam | 0xC0000000, &up)) && up) keystrokes_->KeyUp(vk, lParam | 0xC0000000, &up);
    }
};

void setLearned(bool marked) {
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    std::wstring name = path;
    name = name.substr(name.find_last_of(L'\\') + 1);
    CharLowerBuffW(name.data(), static_cast<DWORD>(name.size()));
    if (marked) {
        const std::wstring value = name + L'\0' + L'\0';
        RegSetKeyValueW(HKEY_CURRENT_USER, L"Software\\Xattot\\InputMethod", L"LearnedMarkedApps", REG_MULTI_SZ,
                        value.c_str(), static_cast<DWORD>(value.size() * sizeof(wchar_t)));
    } else {
        RegDeleteKeyValueW(HKEY_CURRENT_USER, L"Software\\Xattot\\InputMethod", L"LearnedMarkedApps");
    }
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
    const bool marked = argc > 1 && std::wstring(argv[1]) == L"--marked";
    SetConsoleOutputCP(CP_UTF8);
    std::printf("%s mode\n", marked ? "marked" : "eager");
    // The input method loads into this process and traces every key there; shown when a case fails.
    wchar_t temp[MAX_PATH] = {};
    GetTempPathW(MAX_PATH, temp);
    const std::wstring trace = std::wstring(temp) + L"xattot-imetest-trace.txt";
    DeleteFileW(trace.c_str());
    SetEnvironmentVariableW(L"XATTOT_IME_TRACE", trace.c_str());
    setLearned(marked);
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    ITfThreadMgr* threadMgr = nullptr;
    TfClientId client = TF_CLIENTID_NULL;
    HRESULT hr = CoCreateInstance(CLSID_TF_ThreadMgr, nullptr, CLSCTX_INPROC_SERVER, IID_ITfThreadMgr,
                                  reinterpret_cast<void**>(&threadMgr));
    if (SUCCEEDED(hr)) hr = threadMgr->Activate(&client);
    if (FAILED(hr)) {
        std::printf("FAIL thread manager: 0x%08lx\n", hr);
        return 1;
    }
    ITfInputProcessorProfileMgr* profiles = nullptr;
    hr = CoCreateInstance(CLSID_TF_InputProcessorProfiles, nullptr, CLSCTX_INPROC_SERVER, IID_ITfInputProcessorProfileMgr,
                          reinterpret_cast<void**>(&profiles));
    if (SUCCEEDED(hr)) {
        hr = profiles->ActivateProfile(TF_PROFILETYPE_INPUTPROCESSOR, uzbekLatin, textService, profile, nullptr,
                                       TF_IPPMF_FORPROCESS | TF_IPPMF_DONTCARECURRENTINPUTLANGUAGE);
    }
    if (FAILED(hr)) {
        std::printf("FAIL activating Özbekça (Xattot): 0x%08lx\n", hr);
        return 1;
    }
    TF_INPUTPROCESSORPROFILE active = {};
    profiles->GetActiveProfile(GUID_TFCAT_TIP_KEYBOARD, &active);
    if (!IsEqualCLSID(active.clsid, textService)) {
        std::printf("FAIL the active keyboard profile is not Özbekça (Xattot)\n");
        return 1;
    }

    const HKL us = LoadKeyboardLayoutW(L"00000409", KLF_NOTELLSHELL);
    int failures = 0;
    {
        Typist typist(threadMgr, client, us);
        for (const Case& c : cases) failures += typist.run(c) ? 0 : 1;
    }
    setLearned(false);
    profiles->Release();
    threadMgr->Deactivate();
    threadMgr->Release();
    CoUninitialize();
    if (failures > 0) {
        std::printf("input method trace:\n");
        std::fflush(stdout);
        std::ifstream log(trace);
        std::cout << log.rdbuf() << std::flush;
    }
    std::printf(failures == 0 ? "all passed\n" : "%d failed\n", failures);
    return failures == 0 ? 0 : 1;
}
