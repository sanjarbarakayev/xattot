# Xattot

Type the new Uzbek Latin alphabet (law OʻRQ-1184) on a Mac: type `ch` and get `ç`.
Xattot ("calligrapher") is a native keyboard layout, Özbek (Lotin), plus an
optional menu bar app that switches to it with one shortcut.

The layout needs no background app and no Accessibility permission: it is a
standard `.keylayout` with dead keys, so it works in every app.

## Typing

- `ch` → `ç`, `sh` → `ş`, `o'` → `ö`, `g'` → `ğ` (backtick works instead of `'`)
- `Ch`/`CH` → `Ç`, `Sh`/`SH` → `Ş`, `O'` → `Ö`, `G'` → `Ğ`
- `c`, `s`, `o`, `g` wait for the next key; if it completes no letter, both are typed as is.
  Return arrives together with a waiting letter, as text, so chat apps that send on Return
  start a new line instead (`emas` + Return); a space first, or a second Return, sends
- `Option+C/S/G/O` types `ç ş ğ ö` directly (with Shift: `Ç Ş Ğ Ö`)
- `Option+H` types an `h` that never joins a digraph: `p u s Option+H` → `push`
- `'` between two letters becomes the tutuq `ʼ` (U+02BC): `san'at` → `sanʼat`. Before a
  word or after one it stays `'`, so quotes are kept. `Option+'` types `ʼ` anywhere
- A word with `w`, or `c` not followed by `h`, cannot be Uzbek: its remaining letters type
  as is, so `wish`, `watch`, `cash` and `code` stay intact. The next space or punctuation
  turns digraphs back on
- Everything else matches ABC, including its accent dead keys and Cmd/Ctrl shortcuts

English words without such a letter still join: `push` and `shop` become `puş` and
`şop`, `don't` gets a tutuq (`donʼt`), and a quoted `'tag'` becomes `'tağ`. Use `Option+H` for a single word, and
switch to ABC for English prose and code.

Single-letter shortcuts do not fire in Chromium browsers (Chrome, Arc, Edge) and
Electron apps (Slack, VS Code, the Claude desktop app): `a` to archive, `j`/`k` to
move, `c` to compose in Gmail or GitHub. Chromium reports a key that leaves the
layout in a dead-key state as `Dead`, and every letter here does, to remember it is
inside a word. A keylayout cannot avoid that without breaking the tutuq. Typing and
Cmd/Ctrl shortcuts are unaffected; switch to ABC with `Ctrl+Option+O` while you
use letter shortcuts.

## Menu bar app

`Xattot.app` puts an Ö in the menu bar (filled when on, outlined when off)
and toggles the layout with a global shortcut, ⌃⌥O by default (⌃Space and ⌃⌥Space
belong to the system input menu). The menu changes the shortcut and turns on
launch at login, which the app also offers once, after the layout is enabled. Turning off returns to the source used before, else ABC.

- Ships the layout inside and copies it to `~/Library/Keyboard Layouts` on launch
  (replaced whenever the layout's content hash changes), then deletes macOS's cached
  input source tables. Sandboxed apps keep their own, and one made before the install
  crashes the app when Fn switches to the layout
- The first time it enables the layout, macOS 26 shows a generic consent prompt
  for third-party input sources; the app explains it beforehand, then selects
  Özbek as soon as the user allows it
- Switches to ABC while a password field has focus and back when it loses it.
  macOS keeps any Latin layout on in password fields, so `sh` would type `ş` into a
  password. The app polls the system's secure input flag, which says only that some
  app holds secure input. With Terminal's Secure Keyboard Entry on, Terminal counts as
  one. The bare layout cannot do this
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

- **The layout is data, not code.** `Uzbek Latin.keylayout` is an XML table of
  which key types which letter. macOS runs nothing from it, and it has nowhere to
  send anything. Open it in any text editor.
- **The app cannot reach the network.** It links no networking library and
  imports no networking symbol (sockets, URLSession, CFNetwork, Network.framework).
  `scripts/check_no_network.sh` proves it on every CI build, and you can run it on
  the copy you downloaded:
  `scripts/check_no_network.sh "/Applications/Xattot.app"`
- **It never sees what you type.** Carbon delivers only its own shortcut to it.
  It reads the current input source's ID and whether secure input is on, and, while it
  is on, which app was in front when it turned on (to name it in the menu). It writes
  its layout bundle to `~/Library/Keyboard Layouts`, and stores two preferences: the
  shortcut and the source to return to (`defaults read com.sanjarbarakayev.xattot`).
  It quits another app only when you confirm "qayta işga tuşiriş" in its menu.
- **The release is built from this source.** GitHub Actions builds the DMG from
  the tagged commit, publishes its SHA-256 and a signed build provenance
  attestation. Check a download with:
  `gh attestation verify Xattot.dmg --repo sanjarbarakayev/xattot`
- **Small enough to read.** About 950 lines of Swift and 550 of Python.

The macOS prompt on first enable ("will be able to access anything you type")
is Apple's fixed text for every third-party input source, including input
methods that do run code. A `.keylayout` is not one of those.

The app is not sandboxed: App Sandbox restricts the Text Input Sources API, and
the sandboxed build could not see the enabled layout. The no-network check above
stands in for the network half of what a sandbox would guarantee.

## Commands

```bash
make test       # layout unit tests + DTD validation + app logic tests
make install    # build the layout and copy it to ~/Library/Keyboard Layouts
make verify     # check the installed layout through macOS UCKeyTranslate
make app        # dist/Xattot.app
make dmg        # dist/Xattot.dmg and dist/Xattot-layout.zip
make uninstall
```

Without the app, add the layout in System Settings > Keyboard > Input Sources > Edit > +
(search "Özbek"). Log out and back in if it is not listed yet.

## Layout

- `uzkbd/keys.py` — ABC key codes and per-layer characters
- `uzkbd/rules.py` — digraphs, Option letters, accent dead keys
- `uzkbd/layout.py` — builds layers, actions and terminators
- `uzkbd/xml_writer.py` — emits `.keylayout` XML 1.1
- `uzkbd/simulator.py` — interprets the XML with macOS dead-key semantics (tests)
- `uzkbd/bundle.py` — writes the `.bundle` (Info.plist, localized name, template icon)
- `app/Sources/` — menu bar app: toggle logic, TIS wrapper, hotkey, icon, installer, move to Applications
- `app/Tests/` — app logic tests (plain runner; Command Line Tools have no XCTest)
- `scripts/` — app build, install, uninstall, icon rendering, installed-layout check, no-network check
- `scripts/dmg/` — DMG background art and dmgbuild settings
- `.github/workflows/build.yml` — tests, DMG, no-network check, checksum; releases on `v*` tags

## License

MIT
