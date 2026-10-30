#pragma once

#include <string>

namespace xattot::test {

// `data` is inputmethod/: the parity fixtures and word lists both engines share.
void runEngineTests(const std::string& data);
void runHostTests();

}  // namespace xattot::test
