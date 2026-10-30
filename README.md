# Xattot

Type the new Uzbek Latin alphabet (law OʻRQ-1184) on a Mac: type `ch` and get `ç`.
Xattot ("calligrapher") is an input method, Özbekça (Xattot), and a native keyboard
layout, Özbekça Tugmali (Xattot), plus a menu bar app that installs them and switches
between them with one shortcut.

Both are also available for [Windows](#windows).

The menu bar app has two Özbek modes, and the input method is the default:

- **Özbekça (Xattot)**, the input method. It types the new letters as digraphs and
  fixes what a layout cannot, because it sees the whole word (see
  [Input method](#input-method))
- **Özbekça Tugmali (Xattot)**, the layout that gives each new letter its own key

Neither needs Accessibility permission.

## Input method

Özbekça (Xattot) is an input method. It sees the word being typed, so a digraph is
decided with the whole word in view:

- `ch` → `ç`, `sh` → `ş`, `o'` → `ö`, `g'` → `ğ` (backtick works instead of `'`)
- `Ch`/`CH` → `Ç`, `Sh`/`SH` → `Ş`, `O'` → `Ö`, `G'` → `Ğ`
- `Option+C/S/G/O` types `ç ş ğ ö` directly (with Shift: `Ç Ş Ğ Ö`)
- `Option+H` types an `h` that never joins a digraph: `p u s Option+H` → `push`
- `'` between two letters becomes the tutuq `ʼ` (U+02BC): `san'at` → `sanʼat`. Before a
  word or after one it stays `'`, so quotes are kept. `Option+'` types `ʼ` anywhere
- A word with `w`, or `c` not followed by `h`, cannot be Uzbek: its remaining letters type
  as is, so `wish`, `watch`, `cash` and `code` stay intact
- English words without such a letter keep their spelling too: `change`, `push`, `shop`,
  `Chrome`, `don't`, a quoted `'video'`, a Markdown `` `log` ``
- Return, Tab, Escape and arrows never meet a pending letter, so chat apps send on Return and
  Spotlight opens Arc after `arc` + Return
- Letters reach Chromium and Electron as plain keys, so single-letter shortcuts work
- After a typo and Backspace, `s` still joins `h`
- A word that turns out foreign (`show-off`) gets its earlier `ş` reverted
- Everything else matches ABC, including its accent dead keys and Cmd/Ctrl shortcuts

The rules come from the old digraph keylayout, which is no longer shipped: it is kept in
`uzkbd/` as the rules reference that the input method's parity tests are generated from.
A `.keylayout` could not avoid its limits (English words turned into Uzbek letters,
Return and Spotlight arriving as text, Chromium seeing every letter as `Dead`), which is
why it was replaced.

The menu bar app installs the input method into `~/Library/Input Methods` on launch.
The first time you enable it, macOS shows the same consent prompt as for any
third-party input source.

## Tugmali

Özbekça Tugmali (Xattot) puts each new letter on its own key, so nothing waits for a
second key:

- `[` → `ö`, `]` → `ğ`, `;` → `ş`, `'` → `ç` (with Shift: `Ö Ğ Ş Ç`)
- The backtick key types the tutuq `ʼ` (U+02BC); Shift gives `~`, Option the backtick
- A symbol pushed off its key stays on that key behind Option: `Option+[` is `[`,
  `Shift+Option+]` is `}`, `Option+;` is `;`, `Shift+Option+'` is `"`
- `Option+9`/`Option+0` type `“` `”`, and with Shift `‘` `’`. `«` `»` stay on
  `Option+\` and `Shift+Option+\`, as in ABC
- Everything else matches ABC, including its Option accent keys and Cmd/Ctrl shortcuts

Plain typing has no waiting letters: single-letter shortcuts work in Chromium browsers
and Electron apps, Spotlight takes Return, and Return sends in chat apps. The cost is
relearning five keys, plus the symbols that moved behind Option. Pick it if you would
rather have a layout, which is data and runs no code, than an input method.

The menu bar app keeps only one of the two modes enabled at a time. Its menu has a
radio item for each; the first time a mode is enabled, macOS asks for consent.

## Windows

`Xattot-Setup.exe` installs both keyboards on Windows 10 and 11, 64-bit (x64 and ARM64),
with Özbekça (Xattot) first in the Uzbek list, so it is the default.

**Özbekça (Xattot)**, the input method, is the Mac one ported to C++ as a Text Services
Framework (TSF) text service: the same digraphs, tutuq, English guard and per-app marked text,
on the US layout. `AltGr+S` (or `Ctrl+Alt+S`) types `ş` directly where the Mac uses Option,
and `s`, `AltGr+H` gives `sh`. It loads into every app that takes keyboard focus, x64, 32-bit
and ARM64 alike; on Windows on ARM a single ARM64X DLL serves both native and emulated x64 apps.
It converts nothing in read-only and password fields. Apps learned to need marked text are kept
in `HKCU\Software\Xattot\InputMethod`. To see why a key did or did not convert, start an app with the
`XATTOT_IME_TRACE` environment variable set to a file path: the input method appends each key's
handling there, including the text it read, so use it only for debugging. Like on the Mac, it reads only the word before the caret
and links no networking code; the build fails if it imports a networking DLL.

**Özbekça Tugmali (Xattot)** types the same keys as on the Mac, with AltGr (right Alt,
or Ctrl+Alt) in Option's place:

- `[` `]` `;` `'` → `ö ğ ş ç`, with Shift or Caps Lock `Ö Ğ Ş Ç`; the backtick key types `ʼ`
- AltGr gives back the displaced symbols: `AltGr+[` is `[`, `Shift+AltGr+[` is `{`, AltGr on the backtick key types `` ` ``
- `AltGr+9`/`AltGr+0` type `“` `”`, with Shift `‘` `’`; `AltGr+\` and `Shift+AltGr+\` type `«` `»`
- Everything else matches the US layout, including Ctrl shortcuts. US has no AltGr
  characters, so Mac Option letters such as `å` and the accent dead keys are not carried over

The installer asks for administrator rights once. It copies `kbduzxt.dll` to `System32`
(and the 32-bit-app build to `SysWOW64`) and registers it under
`HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts`; it copies `XattotIME.dll` to
`Program Files\Xattot` (and the 32-bit build to `x86\`) and registers it with `regsvr32`; then
it adds both to the signed-in user's Uzbek (Latin) language. It is listed in Settings > Apps as
Xattot, and uninstalling there reverses all of it. Installing a new version over an old one keeps
the same entries, even while Windows or open apps have the old DLLs loaded. The installer is
unsigned, so SmartScreen warns on first run: More info > Run anyway.

Digraphs need the input method: a Windows keyboard layout remembers a single dead key, so
`toshkent` would stay `toshkent` and `so'z` `so'z` with a layout alone.

The DLL is data, like the `.keylayout`: tables of which key types which character, plus
the one exported function that returns them. It imports nothing; the build fails if it
does, and you can check a copy with `dumpbin /imports kbduzxt.dll`.

## Menu bar app

`Xattot.app` puts an Ö in the menu bar (filled when on, outlined when off)
and toggles the selected Özbekça mode with a global shortcut, ⌃⌥O by default
(⌃Space and ⌃⌥Space belong to the system input menu). The menu changes the shortcut and turns on
launch at login, which the app also offers once, after a layout is enabled. Turning off returns to the source used before, else ABC.

- Ships the layout bundle and the input method inside. On launch it copies the Tugmali bundle to
  `~/Library/Keyboard Layouts` and the input method to `~/Library/Input Methods`
  (each replaced whenever its content hash changes), then deletes macOS's cached
  input source tables. Sandboxed apps keep their own, and one made before the install
  crashes the app when Fn switches to the layout
- The first time it enables a mode, macOS 26 shows a generic consent prompt
  for third-party input sources; the app explains it beforehand, then switches
  to the chosen Özbekça mode as soon as the user allows it
- Switches to ABC while a password field has focus and back when it loses it.
  macOS keeps any Latin layout on in password fields, so `sh` would type `ş` into a
  password. The app polls the system's secure input flag, which says only that some
  app holds secure input. With Terminal's Secure Keyboard Entry on, Terminal counts as
  one. A bare layout cannot do this. The input method needs no such switch: in
  password fields it converts nothing. macOS bypasses input methods in secure text
  fields, and when the app you type in holds secure input itself (Terminal's Secure
  Keyboard Entry, for example) Xattot passes keys through unchanged. So turning the
  input method on works even while a background app holds secure input
- `xattot://toggle`, `xattot://on`, `xattot://off` for Shortcuts/Raycast
- Global hotkey via Carbon `RegisterEventHotKey`: no Accessibility permission
- Universal (arm64 + x86_64), macOS 13+, ad-hoc signed. Without a Developer ID
  other Macs block the first launch; Privacy & Security > Open Anyway allows it
- Started from the DMG or a translocated download, it offers to copy itself to
  Applications and relaunch from there

## Distribution

`make dmg` builds `dist/Xattot.dmg`: a drag-to-Applications window
(background, arrow and icon positions written by
[dmgbuild](https://github.com/dmgbuild/dmgbuild) into `.DS_Store`, no Finder
scripting) with the app and install notes in Uzbek. It also writes
`dist/Xattot-layout.zip`, the bare layout for people who do not want the app.
macOS loads the bare layout even with the quarantine flag that browsers and
Telegram add, since a layout contains no executable code.

## Privacy, and how to check it yourself

A keyboard tool has to earn trust, so every claim here can be verified without
trusting the author.

- **The layout is data, not code.** Tugmali is an XML table of which
  key types which letter. macOS runs nothing from it, and it has nowhere to
  send anything. Open it in any text editor.
- **The input method is code, and it reads text.** To convert a digraph it reads the
  word right before the caret, checks that it is exactly what it typed, and replaces
  only an exact match; any other text is left alone. The only thing it remembers is
  which apps need marked text, as a list of bundle IDs in its own preferences
  (`defaults read com.sanjarbarakayev.inputmethod.xattot learnedMarkedApps`).
  It needs no Accessibility or Input Monitoring permission.
  In password fields it converts nothing: macOS bypasses input methods in secure text
  fields, and when the app you type in holds secure input itself (Terminal's Secure
  Keyboard Entry, for example) Xattot passes keys through unchanged. To tell, it reads
  the secure input flag and, while it is on, which app holds it.
- **Neither app can reach the network.** The menu bar app and the embedded input method
  link no networking library and import no networking symbol (sockets, URLSession,
  CFNetwork, Network.framework). `scripts/check_no_network.sh` checks every executable
  inside the app, the input method included, on every CI build, and you can run it
  on the copy you downloaded:
  `scripts/check_no_network.sh "/Applications/Xattot.app"`
- **The menu bar app never sees what you type.** Carbon delivers only its own shortcut to it.
  It reads the current input source's ID and whether secure input is on, and, while it
  is on, which app was in front when it turned on (to name it in the menu). It writes
  the layout bundle to `~/Library/Keyboard Layouts` and the input method
  (`XattotInputMethod.app`) to `~/Library/Input Methods`, and stores five preferences:
  the shortcut, the source to return to, the chosen mode, and two flags that keep the
  first-launch offers from repeating (`defaults read com.sanjarbarakayev.xattot`).
  It quits another app only when you confirm "qayta işga tuşiriş" in its menu.
- **The release is built from this source.** GitHub Actions builds the DMG from
  the tagged commit, publishes its SHA-256 and a signed build provenance
  attestation. Check a download with:
  `gh attestation verify Xattot.dmg --repo sanjarbarakayev/xattot`
- **Small enough to read.** The menu bar app, the input method and its engine are plain
  Swift built with the Command Line Tools, with no third-party code; Tugmali is
  generated by Python.

The macOS prompt on first enable ("will be able to access anything you type")
is Apple's fixed text for every third-party input source. For the input method it
is literally true, since macOS hands it your keys; the points above say what it does
with them. A `.keylayout` is not code at all.

The app is not sandboxed: App Sandbox restricts the Text Input Sources API, and
the sandboxed build could not see the enabled layout. The no-network check above
stands in for the network half of what a sandbox would guarantee.

## Commands

```bash
make test       # layout unit tests + DTD validation + app logic tests
make install    # build the Tugmali layout and the input method, copy them to ~/Library
make verify     # check the installed layout through macOS UCKeyTranslate
make app        # dist/Xattot.app, with the input method embedded
make dmg        # dist/Xattot.dmg and dist/Xattot-layout.zip
make uninstall  # remove the layout and the input method
make windows    # dist/windows/gen: the generated C tables and typing cases
```

On Windows, `windows\build.bat` builds the DLLs and `dist\Xattot-Setup.exe` (Python 3,
Visual Studio 2022 with the x64 and ARM64 C++ tools, and Inno Setup 6).

The input method's engine and host logic are plain C++20 and build anywhere:

```bash
make -C windows/ime test        # engine, host, parity and key mapping tests
make -C windows/ime crosscheck  # the C++ and Swift engines type the same 110,000 runs alike
make -C windows/ime coverage    # fails below 80% line coverage
```

`make app` and `make install` build the input method too (`inputmethod/scripts/build.sh`).

Without the app, add a layout in System Settings > Keyboard > Input Sources > Edit > +
(search "Özbekça"). Log out and back in if it is not listed yet.

## Layout

- `uzkbd/keys.py` — ABC key codes and per-layer characters
- `uzkbd/rules.py` — digraphs, Option letters, accent dead keys (the rules reference)
- `uzkbd/layout.py` — builds the digraph keylayout, which is no longer shipped: the reference the input method is checked against
- `uzkbd/tugmali.py` — the Tugmali layout: new letters on their own keys, displaced symbols behind Option
- `uzkbd/xml_writer.py` — emits `.keylayout` XML 1.1
- `uzkbd/simulator.py` — interprets the XML with macOS dead-key semantics (tests)
- `uzkbd/bundle.py` — writes the `.bundle` (Info.plist, localized name, template icon)
- `inputmethod/` — the input method: engine, IMK host, app bundle and build script; see its README
- `app/Sources/` — menu bar app: toggle logic, TIS wrapper, hotkey, icon, installer, move to Applications
- `app/Tests/` — app logic tests (plain runner; Command Line Tools have no XCTest)
- `scripts/` — app build, install, uninstall, icon rendering, installed-source check, no-network check
- `scripts/dmg/` — DMG background art and dmgbuild settings
- `uzkbd/windows/` — Tugmali for Windows: US virtual keys, the layout model, C table writer
- `windows/kbd/` — the layout DLL's fixed C source, resources and exports
- `windows/ime/engine/`, `windows/ime/host/` — the input method's engine and host logic, ported from
  `inputmethod/Sources/` and checked against it key by key (`tests/crosscheck/`)
- `windows/ime/tsf/` — the TSF text service: COM registration, key handling, edit sessions, composition
- `windows/installer/` — the Inno Setup script and the per-user language list helper it installs
- `windows/build.bat` — builds the layout (x64, ARM64, wow64) and input method (x64, ARM64X, x86)
  DLLs and `dist/Xattot-Setup.exe`
- `windows/tests/` — runs the installer silently, checks what it registered, types every key through
  the installed layout with `ToUnicodeEx`, and reads each installed DLL's tables directly (the only
  check that reaches the 32-bit-app build); `imetest` types through the installed input method
  over TSF, in eager and marked mode, as a native and a 32-bit app, and checks that it loads and
  activates there and (on ARM64) in an emulated x64 app. It types only when its window gets the
  foreground: the ARM64 runner's shell windows keep it, so typing is checked on x64
- `.github/workflows/build.yml` — tests, DMG, no-network check, checksum; Windows build, then install,
  typing test, upgrade and uninstall on x64 and ARM64; releases on `v*` tags

## License

MIT
