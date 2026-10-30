# The engine and host logic build anywhere with a C++20 compiler; the TSF text service in tsf/
# builds only on Windows (windows/build.bat).
CXX ?= clang++
CXXFLAGS = -std=c++20 -Wall -Wextra -Werror -O1
INPUTMETHOD = ../../inputmethod
ENGINE = engine/*.cpp
HOST = host/*.cpp
TESTS = tests/FakeClient.cpp tests/Json.cpp tests/EngineTests.cpp tests/HostTests.cpp tests/main.cpp
MIN_COVERAGE = 80

.PHONY: test
test:
	@mkdir -p build
	$(CXX) $(CXXFLAGS) -o build/tests $(ENGINE) $(HOST) $(TESTS)
	build/tests -q $(INPUTMETHOD)

# Types every Swift test input, every parity input and random key strings through both engines
# under every configuration and compares the text after each key.
.PHONY: crosscheck
crosscheck:
	@mkdir -p build
	python3 -I tests/crosscheck/make_corpus.py > build/corpus.txt
	swiftc -swift-version 5 -O -o build/replay-swift $(INPUTMETHOD)/Sources/Engine/*.swift \
		$(INPUTMETHOD)/Tests/FakeClient.swift $(INPUTMETHOD)/Tests/Check.swift tests/crosscheck/main.swift
	$(CXX) $(CXXFLAGS) -o build/replay-cpp $(ENGINE) tests/FakeClient.cpp tests/crosscheck/replay.cpp
	build/replay-swift $(INPUTMETHOD)/Resources < build/corpus.txt > build/replay-swift.txt
	build/replay-cpp $(INPUTMETHOD)/Resources < build/corpus.txt > build/replay-cpp.txt
	@diff build/replay-swift.txt build/replay-cpp.txt > build/crosscheck.diff \
		&& echo "crosscheck: $$(wc -l < build/corpus.txt | tr -d ' ') runs match" \
		|| { head -20 build/crosscheck.diff; echo "crosscheck: the engines differ"; exit 1; }

.PHONY: coverage
coverage:
	@mkdir -p build
	rm -f build/coverage-*.profraw build/coverage.profdata
	$(CXX) $(CXXFLAGS) -fprofile-instr-generate -fcoverage-mapping -o build/tests-cov $(ENGINE) $(HOST) $(TESTS)
	LLVM_PROFILE_FILE=build/coverage-%p.profraw build/tests-cov -q $(INPUTMETHOD)
	xcrun llvm-profdata merge -sparse build/coverage-*.profraw -o build/coverage.profdata
	xcrun llvm-cov report build/tests-cov -instr-profile=build/coverage.profdata $(ENGINE) $(HOST) > build/coverage-report.txt
	@cat build/coverage-report.txt
	@awk -v min=$(MIN_COVERAGE) '/^TOTAL/ { found = 1; pct = $$10 + 0 } \
		END { if (!found) { print "FAIL: no TOTAL line"; exit 1 } \
		if (pct < min) { printf "FAIL: line coverage %.2f%% is below %d%%\n", pct, min; exit 1 } \
		printf "line coverage %.2f%% (minimum %d%%)\n", pct, min }' build/coverage-report.txt
