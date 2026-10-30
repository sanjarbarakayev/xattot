#pragma once

#include <windows.h>

#include <msctf.h>

namespace xattot::tsf {

extern HINSTANCE module;
// Live objects and server locks; the DLL unloads only at zero.
extern LONG objects;

// {FD47E00C-1DD3-4169-B402-BE4F14473EEE}
inline constexpr CLSID textServiceClsid = {0xfd47e00c, 0x1dd3, 0x4169, {0xb4, 0x02, 0xbe, 0x4f, 0x14, 0x47, 0x3e, 0xee}};
// {59E8B67C-4644-47C6-81CE-C0249DD669FA}
inline constexpr GUID profileGuid = {0x59e8b67c, 0x4644, 0x47c6, {0x81, 0xce, 0xc0, 0x24, 0x9d, 0xd6, 0x69, 0xfa}};
// Uzbek (Latin), the language the Tugmali layout is registered for too.
inline constexpr LANGID language = MAKELANGID(LANG_UZBEK, SUBLANG_UZBEK_LATIN);
inline constexpr wchar_t displayName[] = L"Özbekça (Xattot)";

}  // namespace xattot::tsf
