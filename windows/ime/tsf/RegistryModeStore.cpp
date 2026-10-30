#include "RegistryModeStore.h"

#include <windows.h>

#include <vector>

#include "Strings.h"

namespace xattot::tsf {

namespace {

constexpr wchar_t keyPath[] = L"Software\\Xattot\\InputMethod";
constexpr wchar_t valueName[] = L"LearnedMarkedApps";

}  // namespace

std::set<std::string> RegistryModeStore::learnedMarkedApps() const {
    DWORD bytes = 0;
    if (RegGetValueW(HKEY_CURRENT_USER, keyPath, valueName, RRF_RT_REG_MULTI_SZ, nullptr, nullptr, &bytes) != ERROR_SUCCESS) {
        return {};
    }
    std::vector<wchar_t> buffer(bytes / sizeof(wchar_t) + 2, L'\0');
    bytes = static_cast<DWORD>(buffer.size() * sizeof(wchar_t));
    if (RegGetValueW(HKEY_CURRENT_USER, keyPath, valueName, RRF_RT_REG_MULTI_SZ, nullptr, buffer.data(), &bytes) != ERROR_SUCCESS) {
        return {};
    }
    std::set<std::string> apps;
    for (const wchar_t* entry = buffer.data(); *entry; entry += wcslen(entry) + 1) apps.insert(toUtf8(entry));
    return apps;
}

void RegistryModeStore::learnMarkedApp(const std::string& app) {
    auto apps = learnedMarkedApps();
    apps.insert(app);
    save(apps);
}

void RegistryModeStore::forgetMarkedApp(const std::string& app) {
    auto apps = learnedMarkedApps();
    apps.erase(app);
    save(apps);
}

void RegistryModeStore::save(const std::set<std::string>& apps) const {
    std::wstring value;
    for (const std::string& app : apps) value += toWide(app) + L'\0';
    value += L'\0';
    RegSetKeyValueW(HKEY_CURRENT_USER, keyPath, valueName, REG_MULTI_SZ, value.c_str(),
                    static_cast<DWORD>(value.size() * sizeof(wchar_t)));
}

}  // namespace xattot::tsf
