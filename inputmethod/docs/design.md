# Input method design

The reasoning behind `inputmethod/`: why an input method, how the engine composes
text, what the spike on real apps found, and what is left to build. The engine
described here exists and is tested; the input method host around it does not yet
(#9).

## 1. Why an input method

The Özbek (Lotin) layout is a `.keylayout`: data, no code, so it sees one key and a
small state, never a word. Every rough edge left in it comes from that:

- English words without `w`/`c` get Uzbek letters: `change` → `çange`, `push` → `puş`.
- Return after a pending letter (`emas` + Return) arrives as text, so chat apps add
  a line instead of sending.
- Spotlight drops Return and arrows while a pending letter is marked text
  (`arc` + Return does nothing).
- Chromium and Electron see every letter as `event.key = "Dead"`, so single-letter
  shortcuts (Gmail, GitHub, Slack) never fire.
- After a typo and Backspace, a preceding `s` no longer joins with `h`.
- A closing quote after `o`/`g` and Markdown backticks become `ö`/`ğ`; `don't` gets
  a tutuq.
- Particle hyphenation (`qildikku` → `qildik-ku`) and spell checking are impossible.

An input method (InputMethodKit) can type the same alphabet with the same habits
(`ch`, `sh`, `o'`, `g'`, `'` for the tutuq) without these problems, because it sees
the word being typed. Spelling and particles can later build on the same engine.

Success looks like this: a whole working day of typing in Telegram, Slack, a
browser, VS Code, Terminal and Spotlight without switching to ABC, and without
noticing the input method except when it prevents a wrong letter.

## 2. Goals and anti-goals

Goals, in order:

1. The same typing rules as the layout, proven by shared test cases.
2. Fix every limit listed above.
3. Keep what the menu bar app does (toggle shortcut, password guard, secure input
   notice), so one app is enough.
4. A foundation that spelling, particles and a settings window plug into without
   reworking the engine.

Anti-goals, any of which makes it a failure even if it "works":

- Text leaves the Mac. The input method links no networking code, and a
  `check_no_network.sh`-style check enforces it on every build.
- A lost, doubled or reordered character in any app. Silent text corruption is
  worse than every limit the input method fixes.
- Noticeable latency. Budget: under 2 ms of engine time per key at p99
  (measured: a few microseconds).
- Asking for Accessibility or Input Monitoring permission.
- AI, cloud features or telemetry.

## 3. Constraints

- Command Line Tools only (no Xcode): `swiftc` plus scripts that assemble the
  bundle. `codesign`, `notarytool` and `stapler` ship with the Command Line Tools.
  No third-party dependencies.
- macOS 13+.
- Shipping needs a Developer ID signature and notarization (#18). Development runs
  ad-hoc signed: the spike loaded fine from `~/Library/Input Methods`.
- `uzkbd/rules.py` stays the source of truth for the alphabet rules; the engine
  re-expresses them in Swift and parity tests keep the two in step.
- Mac App Store is not a fit: App Sandbox restricts the Text Input Sources API (the
  menu bar app's sandboxed build could not see its own layout), and input methods
  install into `~/Library/Input Methods`.

## 4. Suggested host shape

- The menu bar app embeds the input method and installs it into
  `~/Library/Input Methods`, the way `LayoutInstaller` installs the layout today
  (content-hash replacement, cache drop).
- The input source uses the ABC base layout and its own source ID, next to the
  Özbek (Lotin) layout; the app's toggle and password guard treat both as Uzbek.
- On first enable it offers to disable the plain layout so two Uzbek sources do
  not fight over the shortcut; disabling the input method re-enables the layout.

## 5. Engine

`Engine.handle(Key) -> [Edit]` is a value type with no AppKit or IMK, so it runs in
the plain test runner and in a benchmark. `Key` is a character (with an Option
flag), a named key, or a shortcut; `Edit` is `pass` (the app types the key from the
ABC base layout), `insert`, `replace(expected:with:)`, or, in marked mode,
`setMarked` and `commit`. The host contract is documented on `Key` and `Edit`.

The engine keeps the current word as pieces (the raw keys and what was typed for
them, `sh` → `ş`) and applies the layout's rules: digraphs `ch sh o' g'` (backtick
too for `o`/`g`), capitals, tutuq between letters, the `w` / non-`ch` `c` foreign
guard, Option letters. Deliberate differences from the layout are listed in
`Tests/divergences.json`:

- It knows the whole word: `h` after `s` joins even after Backspace, and a word
  that turns foreign later (`show-off`) gets its earlier `ş` reverted.
- Nothing is left pending in the client, so Return, Tab, Escape and arrows always
  meet a clean field. The word ends on Space, punctuation, those keys, a shortcut,
  or a focus or caret change.
- **English guard.** At the boundary, a word that formed `ç ş ö ğ` but whose raw
  spelling is English gets the raw spelling back (`change`, `push`, `shop`,
  `don't`, `Chrome`). The list is SCOWL size 50 with contractions (BSD-style
  licence; keep its copyright notice with any build). `wordfreq` data is CC-BY-SA
  and is not used.
- **Uzbek wins collisions.** `Resources/uzbek-exceptions.txt` lists native Uzbek
  words that are also English spellings (`boş`, `tuş`, `çin`, `çap`, `çop`,
  `şam`, `şim`, `çit`, `şod`, `huş`, `marş`, `daça`, `çi`, `şirk`); they always
  stay Uzbek. Loans that are also English terms (`chat`, `chip`, `sushi`) stay
  English. A test checks that every entry really collides. No permissively
  licensed Uzbek word list is known: hunspell/aspell `uz` is GPL and in the old
  alphabet.
- **Quotes and code.** A closing `'` or backtick that matches the mark which opened
  the word is a quote, not part of `o'`/`g'`: it is shown as `ö`/`ğ` while the word
  is open and split back at the boundary, so `'o'zbek'` still gives `'özbek'`. A
  backtick that opens a word starts a code span with no conversions until the
  closing backtick, Return, Tab, Escape, an arrow or a shortcut.

## 6. Composition

**Eager typing with verified replacement (default).** Every key is typed by the app
itself: the input method returns `false`, the key goes through the ABC base layout,
and no marked text exists. When a key completes a digraph, the engine asks for a
replacement of the whole tracked word; the host reads the text before the caret
(`selectedRange` + `attributedSubstring(from:)`) and replaces it only if it is
exactly what the engine typed. This is how macOS's own press-and-hold accent menu
edits text. A failed check edits nothing and the word stops being tracked; the
worst case is an unconverted `sh`, never a corrupted character, and a moved caret
always fails the check.

Marked text was the first choice; the spike rejected it as the default because
Telegram saw marked text at the moment of Return and made a new line instead of
sending.

**Marked mode, per app.** Monaco editors (VS Code, Cursor, Windsurf) apply the
replacement to the document but keep reporting the old text, so every later check
in the word fails (`push` stayed `puş`). There only the undecided part of a word
is marked text: a pending opener, or a converted span that could still be an
English word. Marked mode is a presentation layer over the eager engine, so the
rules exist once; text already committed is never edited.

`AppModes` chooses the mode: seeded with the three Monaco editors; learned and
persisted when a failed check finds exactly the pre-replacement text (each digraph
back to its opener, `pus` for `puş`). The check must not run right after a
replacement, because Chromium updates its text asynchronously; an immediate
readback wrongly flagged an Electron app in the spike. A client that reports no
text at all is marked only after three nils in a row, for the session, so a
transient nil cannot push a chat app into marked mode for good. `forget(_:)`
undoes a learned app; `switchMode(_:)` flushes the word before changing mode.

## 7. Input method host (to build, #9)

An IMK server: `IMKServer` with the connection name from its Info.plist and one
`IMKInputController` that turns `NSEvent`s into `Key`s, applies `Edit`s and returns
`false` for `pass`. It ends the word in `commitComposition` and on deactivation.

Required, found in the spike:

- **Force the ABC base layout on activation**: `overrideKeyboard(withKeyboardNamed:
  "com.apple.keylayout.ABC")` on the client and
  `TISSetInputMethodKeyboardLayoutOverride(ABC)`. Without it the input method
  inherits the last keyboard layout (usually the Özbek layout), passed keys run
  through its dead keys a second time, and Chromium still sees `Dead`.
- **Drop the input source caches on install** (`com.apple.IntlDataCache.le*` under
  `DARWIN_USER_CACHE_DIR`), as `LayoutInstaller` does. Telegram (App Store,
  sandboxed) crashed with `CFRelease(NULL)` in `TextInputUIMacHelper` on switching
  to the new source until the caches were dropped.
- Map Cmd/Ctrl combos, modified Backspace, forward delete and Home/End/Page keys to
  `.shortcut`; call `endWord()` on focus or caret changes and `reset()` when the
  client is gone.

## 8. Spike results (macOS 26, ISO keyboard)

`spike/imk/` is the throwaway IMK app these come from.

- An ad-hoc signed input method with the hardened runtime loads from
  `~/Library/Input Methods`; `TISRegisterInputSource` + `TISEnableInputSource`
  enable it.
- Telegram: marked text made `emas` + Return a new line; eager typing with verified
  replacement sent the message.
- Spotlight: `arc` + Return opened Arc.
- An Electron app: a single-letter menu shortcut fired once the ABC base layout was
  forced.
- `shahar` → `şahar` by replacement; `push` + Space came back as `push`; `pus`,
  Backspace, `sh` → `puş`.
- Password fields: no conversion, macOS bypasses input methods in secure fields.
- Terminal and Notes: replacement and the English guard work.
- VS Code: the `s` replacement worked but the guard could not verify (`pus` reported
  for `puş`); marked mode fixed `push`, `o'g'il` → `öğil`, `shoshilmoq` →
  `şoşilmoq`, and Return in the editor. Learning detected VS Code on its own and
  left the Electron app in eager mode.
- Not covered: Slack, Safari, Zed individually; tutuq and the foreign guard in a
  live app.

## 9. Testing

- `make test`: unit, behaviour and parity tests (keys in, text out through a fake
  client that verifies every replacement), including stale and smart-quote clients
  and caret clicks.
- `make parity`: regenerates `Tests/parity.json` from `uzkbd` on `origin/main`; the
  tests replay it, and `Tests/divergences.json` holds every deliberate difference.
- `make coverage`: fails below 80% line coverage of `Sources/Engine`.
- `make bench`: fails when p99 per key reaches 2 ms.
- Manual matrix for a release: Telegram, Slack, Arc, Chrome, Safari, Notes, Pages,
  VS Code, Terminal, Spotlight, a password field and a sandboxed app (Fn switching),
  each with digraphs, tutuq, Return to send, Backspace, the English guard and
  single-letter shortcuts.

## 10. Open questions

- Uzbek lexicon sources for spelling (#10): uzWaC, the Leipzig Corpora Collection,
  or text with clear rights. Licences to check first.
- Whether the English guard should be a visible setting or stay an internal
  per-app behaviour.
- Known residual limits: a word continued after an arrow key can come back as
  English (`bo←→sh`); a restored closing quote is straight in smart-quote apps; a
  lone opening backtick suppresses conversion until Return; Backspace counting
  inside a code span can drift with Option dead keys.
