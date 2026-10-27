TMP := $(shell mktemp -d)

.PHONY: test test-layout test-app build app install uninstall verify dmg icon

test: test-layout test-app

test-layout:
	python3 -m unittest discover -s tests -t .

test-app:
	swiftc -swift-version 5 -o $(TMP)/apptests app/Sources/LayoutMode.swift app/Sources/ToggleLogic.swift app/Sources/PasswordGuard.swift app/Sources/LoginOffer.swift app/Sources/Shortcut.swift app/Sources/SecureInputNotice.swift app/Tests/main.swift
	$(TMP)/apptests

build:
	python3 build.py

app:
	./scripts/build_app.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

verify:
	swift scripts/verify_installed.swift 2>/dev/null

dmg:
	./scripts/make_dmg.sh

icon:
	rm -rf dist/AppIcon.iconset dist/Layout.iconset && mkdir -p dist/AppIcon.iconset dist/Layout.iconset
	swiftc -swift-version 5 -o $(TMP)/icon app/Sources/IconArt.swift scripts/icon/main.swift
	$(TMP)/icon filled dist/AppIcon.iconset
	$(TMP)/icon outlined dist/Layout.iconset
	iconutil -c icns dist/AppIcon.iconset -o assets/AppIcon.icns
	iconutil -c icns dist/Layout.iconset -o assets/Layout.icns
