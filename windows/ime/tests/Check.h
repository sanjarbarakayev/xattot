#pragma once

#include <cstdio>
#include <string>

namespace xattot::test {

// Plain assertions runner, the same shape as inputmethod/Tests/Check.swift.
inline int failures = 0;
inline bool quiet = false;

inline void check(bool condition, const std::string& label) {
    if (!condition) ++failures;
    if (!condition || !quiet) std::printf("%s %s\n", condition ? "ok  " : "FAIL", label.c_str());
}

}  // namespace xattot::test
