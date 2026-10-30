# Manual tests

CI tests the rules, the engines, the app logic, and on Windows the installer, typing through the
installed layout and input method, upgrade and uninstall. It cannot restart a Mac, click through
Gatekeeper and consent prompts, or type into real apps. These checks cover that.

Run the sections a change touches before tagging a release. Record the result where the change
is discussed, the release pull request or the issue, in this form:

```
Xattot 0.2.1 (commit abc1234), macOS 26.1, Apple silicon
- [x] 2.1 app running after restart
- [ ] 2.3 xattot://toggle: nothing happened (details below)
```

A test with no recorded result has not been run.

## 1. Clean install (macOS)

On a Mac or a new user account that never had Xattot, with no `~/Library/Input Methods/XattotInputMethod.app`
and no `~/Library/Keyboard Layouts/Xattot.bundle`.

1. Open `Xattot.dmg` and start the app from the DMG. It offers to copy itself to Applications and
   relaunches from there.
2. The first launch is blocked; Privacy & Security > Open Anyway opens it.
3. Ö appears in the menu bar, outlined.
4. Turning it on explains the consent prompt first, then macOS asks. After Allow the menu bar icon
   is filled and Özbekça (Xattot) is the current input source.
5. `toshkent` types `toşkent`, `so'z` types `söz`.

## 2. Launch at login and restart (macOS)

1. Turn a mode on. The app offers launch at login once; accept it, or turn it on in the menu.
2. Restart the Mac and sign in.
   1. The app is running: Ö is in the menu bar.
   2. ⌃⌥O turns Özbek off and on.
   3. `open xattot://toggle`, `xattot://off` and `xattot://on` in Terminal do the same.
   4. With Özbekça Tugmali selected, a password field (a Safari sign-in page) switches to ABC while
      it has focus and back when it loses it. The input method does not switch; it converts nothing
      in the field.
3. Turn launch at login off in the menu, restart: the app is not running.

## 3. Upgrade (macOS)

Start from the previous release, with a mode on and the login offer already answered.

1. Replace the app in Applications with the new build and launch it.
2. The login offer does not appear again, and launch at login keeps its setting.
3. The selected mode is still selected and types as before.
4. The installed copies match the ones inside the new app; both commands print nothing:
   ```
   diff -r /Applications/Xattot.app/Contents/Resources/Xattot.bundle ~/Library/Keyboard\ Layouts/Xattot.bundle
   diff -r /Applications/Xattot.app/Contents/Resources/XattotInputMethod.app ~/Library/Input\ Methods/XattotInputMethod.app
   ```
5. Repeat section 2.2 after a restart.

## 4. Typing in real apps (macOS, input method)

1. Chrome or an Electron app (Slack, VS Code): single-letter shortcuts work, for example `j`/`k` in
   Gmail or `/` to focus search.
2. Telegram or Slack: Return sends the message on the first press.
3. Spotlight: `arc` + Return opens Arc (or any app whose name has no digraph).
4. A password field in Safari: `sh` stays `sh`.
5. Terminal with Secure Keyboard Entry on: keys type unchanged.

## 5. Windows

The CI job installs, checks the registry, types every key, upgrades and uninstalls on x64 and ARM64.
By hand:

1. Running `Xattot-Setup.exe` shows SmartScreen; More info > Run anyway installs it.
2. Özbekça (Xattot) is first in the Uzbek (Latin) list after install, and `Win+Space` switches to it.
3. Notepad, a Chromium browser and an Office app: `toshkent` types `toşkent`, `so'z` types `söz`.
4. A password field (a browser sign-in page): nothing converts.
5. Sign out and back in: both keyboards are still in the list.
