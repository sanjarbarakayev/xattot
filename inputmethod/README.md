# Input method engine (experimental)

A pure Swift engine for an Uzbek new-alphabet input method: the same typing habits
as the Özbek (Lotin) layout (`ch`, `sh`, `o'`, `g'`, `'` for the tutuq), without
the limits a `.keylayout` has. It is not part of the release: the DMG ships the
layout and the menu bar app only, and their "data, not code" promise is unchanged.
An input method built on this engine would read typed text in order to fix it; it
must stay offline and keep the text on the Mac.

What a keylayout cannot do and this engine handles, because it sees the whole word:

- English words without `w` or `c` keep their spelling: `change`, `push`, `shop`,
  `Chrome`, `don't`, a quoted `'video'`, a Markdown `` `log` ``.
- Return, Tab, Escape and arrows never meet a pending letter, so chat apps send
  on Return and Spotlight opens `arc` + Return.
- Letters reach Chromium and Electron as plain keys, so single-letter shortcuts work.
- After a typo and Backspace, `s` still joins `h`.
- A word that turns out foreign (`show-off`) gets its earlier `ş` reverted.

Only the engine exists. The IMK controller, installer and menu are open work; `docs/design.md` has the full reasoning.

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

## What the spike showed (macOS 26)

A throwaway IMK app in `spike/imk/` tested the approach on real apps:

- An ad-hoc signed input method with the hardened runtime loads from
  `~/Library/Input Methods`; development needs no Developer ID.
- Marked text broke Telegram (Return made a new line); eager typing with verified
  replacement sent the message. Spotlight, Notes, Terminal and an Electron app
  worked the same way, and single-letter shortcuts fired in the Electron app.
- The input method must force the ABC base layout on activation
  (`overrideKeyboard` on the client and `TISSetInputMethodKeyboardLayoutOverride`).
  Otherwise it inherits the last layout, keys go through its dead keys twice, and
  Chromium still sees `Dead`.
- Sandboxed apps (Telegram from the App Store) crash on switching to a new input
  source until the input source caches are dropped, as the menu bar app's
  `LayoutInstaller` does.
- Password fields bypass input methods.

## Commands

```bash
make test         # unit, behaviour and parity tests
make coverage     # fails below 80% line coverage of Sources/Engine
make bench        # fails when p99 per key reaches 2 ms
make parity       # regenerates Tests/parity.json from uzkbd on origin/main
make english-list # rebuilds Resources/english-words.txt from the pinned SCOWL tarball
```

Command Line Tools are enough; no Xcode. `Tests/divergences.json` lists every case
where the engine deliberately types something other than the layout, with the reason.

## Licences

The engine is MIT, like the rest of the repository. `Resources/english-words.txt` is
generated from SCOWL; its copyright notice is in `Resources/SCOWL-COPYRIGHT.txt` and
must ship with any build that bundles the list.
