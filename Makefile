TMP := $(shell mktemp -d)

.PHONY: test test-layout test-app build app install uninstall verify dmg icon windows

test: test-layout test-app

test-layout:
	python3 -m unittest discover -s tests -t .

test-app:
	swiftc -swift-version 5 -o $(TMP)/apptests app/Sources/LayoutMode.swift app/Sources/ToggleLogic.swift app/Sources/PasswordGuard.swift app/Sources/LoginOffer.swift app/Sources/Shortcut.swift app/Sources/SecureInputNotice.swift app/Sources/BundleInstaller.swift app/Sources/Quarantine.swift app/Sources/LayoutInstaller.swift app/Sources/InputSources.swift app/Tests/main.swift
	$(TMP)/apptests

build:
	python3 -m uzkbd.build

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
	# The Windows input method's icon, at the sizes the taskbar and Settings ask for.
	rm -rf dist/ico && mkdir -p dist/ico
	for n in 16 20 24 32 40 48 64 256; do sips -s format png -Z $$n assets/AppIcon.icns --out dist/ico/$$n.png > /dev/null; done
	python3 -I scripts/icon/make_ico.py assets/Xattot.ico dist/ico/*.png

windows:
	python3 -m uzkbd.windows.build
