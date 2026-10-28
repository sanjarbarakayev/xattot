TARGET = -target arm64-apple-macos13
SWIFTC = swiftc -swift-version 5 $(TARGET)
ENGINE = Sources/Engine/*.swift
MIN_COVERAGE = 80

.PHONY: test
test:
	@mkdir -p build
	$(SWIFTC) -o build/tests $(ENGINE) Tests/*.swift
	build/tests

.PHONY: bench
bench:
	@mkdir -p build
	$(SWIFTC) -O -o build/bench $(ENGINE) Bench/main.swift
	build/bench

.PHONY: coverage
coverage:
	@mkdir -p build
	rm -f build/coverage-*.profraw build/coverage.profdata
	$(SWIFTC) -profile-generate -profile-coverage-mapping -o build/tests-cov $(ENGINE) Tests/*.swift
	LLVM_PROFILE_FILE=build/coverage-%p.profraw build/tests-cov
	xcrun llvm-profdata merge -sparse build/coverage-*.profraw -o build/coverage.profdata
	xcrun llvm-cov report build/tests-cov -instr-profile=build/coverage.profdata $(ENGINE) > build/coverage-report.txt
	@cat build/coverage-report.txt
	@awk -v min=$(MIN_COVERAGE) '\
		/^Filename/ { n = split($$0, h, /  +/); for (i = 1; i <= n; i++) if (h[i] == "Lines") col = i + 2 } \
		/^TOTAL/ { found = 1; pct = $$col + 0; ok = (col > 0 && $$col ~ /%$$/) } \
		END { \
			if (!found || !ok) { print "FAIL: no parsable TOTAL line coverage in the report"; exit 1 } \
			if (pct < min) { printf "FAIL: line coverage %.2f%% is below %d%%\n", pct, min; exit 1 } \
			printf "line coverage %.2f%% (minimum %d%%)\n", pct, min }' build/coverage-report.txt

.PHONY: english-list
english-list:
	scripts/build_english_list.sh > /dev/null

.PHONY: parity
parity:
	python3 -I scripts/export_parity.py
