# Input method

The Özbekça (Xattot) input method: the same typing habits as the old digraph keylayout
(`ch`, `sh`, `o'`, `g'`, `'` for the tutuq), without the limits a `.keylayout` has.
It ships inside Xattot.app and is the menu bar app's default Özbek mode; the Tugmali
layout stays data, not code. The input method reads the word before the caret to fix it, so it
must stay offline and keep the text on the Mac: it links no networking code, and
`../scripts/check_no_network.sh` checks it on every build.

It has three parts:

- `Sources/Engine/`: the pure Swift engine, no AppKit or IMK
- `Sources/Host/`: the logic between IMK and the engine (key mapping, applying edits
  to the text client with verified replacement, the secure input decision, the
  learned-app store), testable without a window server
- `App/`: the IMK app itself, source ID `com.sanjarbarakayev.inputmethod.xattot`,
  display name Özbekça (Xattot)

What a keylayout cannot do and this engine handles, because it sees the whole word:

- English words without `w` or `c` keep their spelling: `change`, `push`, `shop`,
  `Chrome`, `don't`, a quoted `'video'`, a Markdown `` `log` ``.
- Return, Tab, Escape and arrows never meet a pending letter, so chat apps send
  on Return and Spotlight opens `arc` + Return.
- Letters reach Chromium and Electron as plain keys, so single-letter shortcuts work.
- After a typo and Backspace, `s` still joins `h`.
- A word that turns out foreign (`show-off`) gets its earlier `ş` reverted.

`docs/design.md` has the full reasoning.

## How it works

`Engine.handle(Key) -> [Edit]` is a value type with no AppKit; the host applies
the edits to the text client.

- **Eager mode (default).** Every key is typed by the app itself through the ABC
  base layout. When a key completes a digraph, the engine asks for a verified
  replacement: the host replaces the word only if the text before the caret is
  exactly what the engine typed. A failed check never edits anything; the worst
  case is an unconverted `sh`.
- **Marked mode.** Monaco editors (VS Code, Cursor, Windsurf) keep reporting the
  text as it was before a replacement, so checks there fail. In those apps only
  the undecided part of a word is marked text. Marked mode is a presentation layer
  over the eager engine, so the rules exist once.
- **Per-app modes** (`AppModes`): seeded with the Monaco editors, and learned when
  a check finds exactly the pre-replacement text. Clients that report no text at
  all are marked only after three nils in a row, for the session.
- **English guard.** A word that formed `ç ş ö ğ` but is an English word (bundled
  SCOWL list, size 50, with contractions) gets its raw spelling back at the word
  boundary. Uzbek wins collisions: `Resources/uzbek-exceptions.txt` lists Uzbek
  words that are also English spellings (`boş`, `çin`, `çop` and others).
- **Code spans.** A backtick that opens a word starts a span where nothing is
  converted until the closing backtick or Return.

The contract a host must follow is documented on `Key` and `Edit`.

## What the host does (found by a spike on macOS 26)

- It forces the ABC base layout on activation (`overrideKeyboard` on the client and
  `TISSetInputMethodKeyboardLayoutOverride`). Otherwise it inherits the last layout,
  keys go through its dead keys twice, and Chromium still sees `Dead`.
- Marked text broke Telegram (Return made a new line), so eager typing with verified
  replacement is the default; Spotlight, Notes, Terminal and Electron apps work that way.
- Sandboxed apps (Telegram from the App Store) crash on switching to a new input
  source until the input source caches are dropped, so the menu bar app's installers
  drop them.
- In password fields it converts nothing. macOS bypasses input methods in secure text
  fields; when the app you type in holds secure input itself (Terminal's Secure
  Keyboard Entry, for example), the controller passes every key through unchanged
  (`SecureInputPolicy`, `App/SecureInputHolder.swift`).

## Commands

```bash
make test         # unit, behaviour and parity tests
make coverage     # fails below 80% line coverage of Sources/Engine
make bench        # fails when p99 per key reaches 2 ms
make parity       # regenerates Tests/parity.json from uzkbd on origin/main
make english-list # rebuilds Resources/english-words.txt from the pinned SCOWL tarball
scripts/build.sh  # builds ../dist/XattotInputMethod.app (universal, ad-hoc signed); installs nothing
                  # (make app embeds it in Xattot.app, scripts/install.sh installs it)
```

Command Line Tools are enough; no Xcode. `Tests/divergences.json` lists every case
where the engine deliberately types something other than the layout, with the reason.

## Licences

The engine is MIT, like the rest of the repository. `Resources/english-words.txt` is
generated from SCOWL; its copyright notice is in `Resources/SCOWL-COPYRIGHT.txt` and
must ship with any build that bundles the list.
