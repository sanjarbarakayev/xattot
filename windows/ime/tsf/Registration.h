#pragma once

#include <windows.h>

namespace xattot::tsf {

// What regsvr32 runs for the installer: the COM class, the Özbekça (Xattot) profile for
// Uzbek (Latin) and the TSF categories. Each architecture's DLL registers itself in its own view.
HRESULT registerServer();
HRESULT unregisterServer();

}  // namespace xattot::tsf
