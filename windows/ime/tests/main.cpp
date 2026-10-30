#include <cstdio>
#include <cstring>

#include "Check.h"
#include "Tests.h"

// Usage: tests [-q] <inputmethod directory>
int main(int argc, char** argv) {
    using namespace xattot::test;
    const char* data = "../../inputmethod";
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "-q") == 0) {
            quiet = true;
        } else {
            data = argv[i];
        }
    }
    runEngineTests(data);
    runHostTests();
    if (failures == 0) {
        std::printf("all passed\n");
        return 0;
    }
    std::printf("%d failed\n", failures);
    return 1;
}
