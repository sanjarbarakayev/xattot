#pragma once

#include <windows.h>

#include <cstdarg>
#include <cstdio>
#include <string>

namespace xattot::tsf {

// When the XATTOT_IME_TRACE environment variable names a file, every key's handling is appended
// to it, one line per step. Off otherwise: nothing typed is recorded unless someone asks for it.
class Trace {
public:
    static bool on() { return file() != nullptr; }

    static void line(const char* format, ...) {
        FILE* out = file();
        if (!out) return;
        va_list args;
        va_start(args, format);
        std::vfprintf(out, format, args);
        va_end(args);
        std::fputc('\n', out);
        std::fflush(out);
    }

private:
    static FILE* file() {
        static FILE* const out = [] {
            wchar_t path[MAX_PATH] = {};
            const DWORD length = GetEnvironmentVariableW(L"XATTOT_IME_TRACE", path, MAX_PATH);
            if (length == 0 || length >= MAX_PATH) return static_cast<FILE*>(nullptr);
            FILE* opened = nullptr;
            return _wfopen_s(&opened, path, L"a") == 0 ? opened : nullptr;
        }();
        return out;
    }
};

}  // namespace xattot::tsf
