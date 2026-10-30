# Security

Xattot's input method sees every key you type, and the Windows installer runs with
administrator rights. A flaw in either can expose text, so reports are welcome and taken
seriously.

## Reporting a vulnerability

Report it privately through GitHub: open the repository's **Security** tab and choose
**Report a vulnerability**. Please do not open a public issue or pull request for it.

Include what you can of:

- the Xattot version, and the macOS or Windows version
- which part is affected: the input method, the Tugmali layout, the menu bar app, or the
  Windows installer
- steps to reproduce, and what an attacker gains

You will get a reply in the advisory. Once a fix is released, the advisory is published with
credit to you, unless you prefer to stay unnamed.

## Supported versions

Only the [latest release](https://github.com/sanjarbarakayev/xattot/releases/latest) gets
security fixes.

## What counts

Examples of what to report:

- the input method reading, keeping or changing text beyond the word before the caret
- the input method converting text in a password field or while the app holds secure input
- any way for the app or the input method to send data off the machine
- the installer or the menu bar app writing outside the paths the README lists, or a way to
  make them load or run code they did not ship
- a release whose contents do not match its checksum or build provenance attestation

The [Privacy](README.md#privacy-and-how-to-check-it-yourself) section of the README describes
what each part is meant to do. A behaviour that contradicts it is worth a report.

Not in scope: the warnings macOS Gatekeeper and Windows SmartScreen show because the builds
are not signed with a Developer ID or code signing certificate. They are known and tracked in
the issues.
