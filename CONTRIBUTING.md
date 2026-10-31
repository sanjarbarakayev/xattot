# Contributing to Xattot

Thanks for helping. Xattot is small and has one maintainer, so a short issue before a large
change saves both of us time.

## Before you start

- Bugs and ideas live in [GitHub issues](https://github.com/sanjarbarakayev/xattot/issues).
  Issues labelled `good first issue` are a reasonable place to begin.
- For a typo or an obvious one-line fix, open a pull request directly.
- For anything that changes how a key types, how the app installs, or what the app reads,
  open an issue first and describe the case you hit.
- A security problem is not an issue: see [SECURITY.md](SECURITY.md).

## What you need

- **macOS**: the Xcode Command Line Tools (`xcode-select --install`) and Python 3. Nothing
  else: the app and the input method are plain Swift with no third-party code, and the
  layout tests use only the Python standard library. `make dmg` installs `dmgbuild` into
  `.venv/` on first run.
- **The Windows input method's engine**: any C++20 compiler (`clang++` by default). It builds
  and tests on macOS and Linux too.
- **The Windows build itself**: Windows with Python 3, Visual Studio 2022 with the x64 and
  ARM64 C++ tools, and Inno Setup 6.

## Where things are

The [Layout](README.md#layout) section of the README maps every directory. In short:

- `uzkbd/` holds the typing rules in Python. They generate the Tugmali layouts for both
  platforms and the parity data the input method is tested against.
- `inputmethod/` is the macOS input method: a pure Swift engine, the host logic around it,
  and the IMK app. [`inputmethod/docs/design.md`](inputmethod/docs/design.md) explains why it
  works the way it does.
- `windows/ime/` is the same engine and host logic in C++, plus the TSF text service.
- `app/` is the menu bar app.

## Running the tests

```bash
make test                        # layout and menu bar app tests
make -C inputmethod test         # Swift input method engine and host
make -C windows/ime test         # C++ engine and host, parity cases included
make -C windows/ime crosscheck   # the Swift and C++ engines type the same runs alike
```

`make -C inputmethod coverage` and `make -C windows/ime coverage` fail below 80% line coverage.
Run the ones that cover what you touched; CI runs the rest on macOS and Windows.

Some behaviour only a person can check: a restart, Gatekeeper and consent prompts, typing in real
apps. [docs/manual-tests.md](docs/manual-tests.md) lists those checks and how to record a result.
Testing an open release that way is a good first contribution.

## Formatting and lint

```bash
make lint     # ruff for Python, clang-format for C++, swift-format for Swift
make format   # rewrite files to match
```

ruff and clang-format are installed into `.venv/` at pinned versions, so everyone formats alike.
swift-format comes with your Swift toolchain; CI runs the one in Xcode 26.3, and if yours formats
a line differently, the CI log prints the diff it expects. The settings live in `ruff.toml`,
`.clang-format`, `.swift-format` and `.editorconfig`.

## Rules the code depends on

- **No networking code.** Neither the app nor the input method may link a networking library
  or import a networking symbol. `scripts/check_no_network.sh` fails the build if they do, and
  the Windows build fails if a DLL imports one. Users are told they can check this themselves,
  so it is not negotiable.
- **No third-party code** in the app or the input method. The README promises it is small
  enough to read.
- **Engine changes land in both languages.** A change to `inputmethod/Sources/Engine/` needs the
  same change in `windows/ime/engine/`, and `make -C windows/ime crosscheck` must pass.
- **Generated files are not edited by hand.** `inputmethod/Tests/parity.json`,
  `parity-source.txt` and `Bench/corpus.txt` come from `inputmethod/scripts/export_parity.py`.
- **Tests come with the change.** A bug fix adds a test that fails without it.

## Commits and pull requests

- Write commits, branch names and pull requests in English.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- Branch names follow [Conventional Branch](https://conventionalbranch.org/):
  `fix/tutuq-after-digit`, `feature/homebrew-cask`.
- Keep one change per pull request. Say what you changed, why, and how you checked it, on
  which macOS or Windows version and in which apps if typing behaviour changed.
- CI must be green before review.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE).
