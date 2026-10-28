import Cocoa
import InputMethodKit
import Carbon

// Throwaway: eager commit with verified replacement; tests Return, shortcuts and the English guard.
private let english: Set<String> = ["push", "shop", "change", "check", "chrome", "chin", "show", "should"]
private let openers: Set<Character> = ["s", "S", "c", "C", "o", "O", "g", "G"]

private func convert(_ raw: String) -> String {
    let chars = Array(raw)
    var out = ""
    var i = 0
    while i < chars.count {
        let c = chars[i]
        let next = i + 1 < chars.count ? chars[i + 1] : nil
        switch (c, next) {
        case ("s", "h"?), ("s", "H"?): out.append("ş"); i += 2
        case ("S", "h"?), ("S", "H"?): out.append("Ş"); i += 2
        case ("c", "h"?), ("c", "H"?): out.append("ç"); i += 2
        case ("C", "h"?), ("C", "H"?): out.append("Ç"); i += 2
        case ("o", "'"?), ("o", "`"?): out.append("ö"); i += 2
        case ("O", "'"?), ("O", "`"?): out.append("Ö"); i += 2
        case ("g", "'"?), ("g", "`"?): out.append("ğ"); i += 2
        case ("G", "'"?), ("G", "`"?): out.append("Ğ"); i += 2
        default: out.append(c); i += 1
        }
    }
    return out
}

// Spike diagnostics: NSLog from a background input method did not reach `log show`.
private func spikeLog(_ format: String, _ args: CVarArg...) {
    let line = String(format: format, arguments: args) + "\n"
    let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Logs/XattotSpike.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

@objc(XattotSpikeController)
final class XattotSpikeController: IMKInputController {
    /// The current word as pieces: raw keys and what was typed for them (`sh` -> `ş`).
    private var pieces: [(raw: String, shown: String)] = []
    /// False once the document stopped matching what we typed; no more replacements in this word.
    private var tracking = true
    /// Marked-text mode: raw keys of the undecided span, and raw letters of the word already committed.
    private var markedRaw = ""
    private var markedCommittedRaw = ""

    /// Apps whose reported text goes stale after a replacement (Monaco editors). Seeded, and learned at runtime.
    private static var markedApps: Set<String> = [
        "com.microsoft.VSCode", "com.exafunction.windsurf", "com.todesktop.230313mzl4w4u92",
    ]

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        let client = sender as? IMKTextInput
        if let app = client?.bundleIdentifier(), Self.markedApps.contains(app) {
            return handleMarked(event, client)
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        if !flags.isEmpty {
            finishWord(client)
            return false
        }
        if event.keyCode == 51 { // Backspace: the app deletes one character, we forget its piece
            if !pieces.isEmpty { pieces.removeLast() }
            return false
        }
        guard let chars = event.characters, chars.count == 1, let c = chars.first, c.isLetter || c == "'" || c == "`" else {
            finishWord(client) // Return, Tab, Escape, arrows, space, punctuation
            return false
        }
        if let last = pieces.last, last.raw.count == 1, let opener = last.raw.first,
           let joined = digraph(opener, c) {
            guard tracking, let client, replaceBeforeCaret(client, expected: last.shown, with: joined) else {
                tracking = false
                pieces.append((String(c), String(c)))
                return false
            }
            pieces[pieces.count - 1] = (last.raw + String(c), joined)
            return true
        }
        if !c.isLetter {
            finishWord(client)
            return false
        }
        pieces.append((String(c), String(c)))
        return false // typed by the app from the ABC base layout, so no marked text and no "Dead"
    }

    // Without this the client keeps the last keyboard layout (often the Xattot keylayout),
    // so passed-through keys would go through its dead keys and Chromium would see "Dead".
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        (sender as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.ABC"] as CFDictionary
        if let abc = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first {
            TISSetInputMethodKeyboardLayoutOverride(abc)
        }
    }

    override func commitComposition(_ sender: Any!) {
        finishWord(sender as? IMKTextInput)
    }

    override func deactivateServer(_ sender: Any!) {
        finishWord(sender as? IMKTextInput)
        super.deactivateServer(sender)
    }

    private func digraph(_ opener: Character, _ next: Character) -> String? {
        guard openers.contains(opener) else { return nil }
        let joined = convert(String([opener, next]))
        return joined.count == 1 ? joined : nil
    }

    /// Word boundary: an English word typed with digraphs gets its raw spelling back.
    private func finishWord(_ client: IMKTextInput?) {
        finishMarked(client)
        defer { pieces = []; tracking = true }
        let raw = pieces.map(\.raw).joined()
        let shown = pieces.map(\.shown).joined()
        if raw != shown { spikeLog("boundary: tracking=%d english=%d client=%d", tracking ? 1 : 0, english.contains(raw.lowercased()) ? 1 : 0, client == nil ? 0 : 1) }
        guard tracking, raw != shown, english.contains(raw.lowercased()), let client else { return }
        _ = replaceBeforeCaret(client, expected: shown, with: raw)
    }

    /// Replaces the text right before the caret only if it is exactly what we typed there.
    private func replaceBeforeCaret(_ client: IMKTextInput, expected: String, with text: String) -> Bool {
        let length = (expected as NSString).length
        let caret = client.selectedRange()
        let app = client.bundleIdentifier() ?? "?"
        guard caret.location != NSNotFound, caret.length == 0, caret.location >= length else {
            spikeLog("%@: caret %ld/%ld unusable for length %ld", app, caret.location, caret.length, length)
            return false
        }
        let range = NSRange(location: caret.location - length, length: length)
        let found = client.attributedSubstring(from: range)?.string
        // Monaco's signature: the client still shows the word as it was before our replacements.
        // Chromium catches up asynchronously, so only a later check like this one can tell them apart.
        if let found, found != expected, found == staleView(of: expected) {
            Self.markedApps.insert(app)
            spikeLog("%@: client shows pre-replacement text, marked-text mode from now on", app)
        }
        guard found == expected else {
            // Spike diagnostics on the author's Mac: lengths only, plus whether text came back at all.
            spikeLog("%@: mismatch at %ld, expected %ld chars, got %@", app, range.location, length,
                  found.map { "\(($0 as NSString).length) chars: [\($0.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " "))]" } ?? "nil")
            return false
        }
        spikeLog("%@: replaced %ld chars at %ld", app, length, range.location)
        client.insertText(text, replacementRange: range)
        return true
    }

    /// What a client that ignores our replacements would still show: each digraph back to its opener.
    private func staleView(of expected: String) -> String? {
        guard expected == pieces.map(\.shown).joined() else { return nil }
        return pieces.map { $0.raw.count > 1 ? String($0.raw.first!) : $0.shown }.joined()
    }

    // MARK: Marked-text mode (first spike approach, kept for clients like Monaco)

    private func handleMarked(_ event: NSEvent, _ client: IMKTextInput?) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        if !flags.isEmpty {
            finishMarked(client)
            return false
        }
        if event.keyCode == 51 {
            if markedRaw.isEmpty {
                if !markedCommittedRaw.isEmpty { markedCommittedRaw.removeLast() }
                return false
            }
            markedRaw.removeLast()
            showMarked(client)
            return true
        }
        guard let chars = event.characters, chars.count == 1, let c = chars.first else {
            finishMarked(client)
            return false
        }
        let joins = (c == "'" || c == "`") && markedRaw.last.map { "oOgG".contains($0) } == true
        guard c.isLetter || joins else {
            finishMarked(client)
            return false
        }
        if markedRaw.isEmpty && !openers.contains(c) {
            markedCommittedRaw.append(c)
            return false
        }
        markedRaw.append(c)
        let full = (markedCommittedRaw + markedRaw).lowercased()
        if convert(markedRaw) != markedRaw && english.contains(where: { $0.hasPrefix(full) }) {
            showMarked(client)
        } else if let last = markedRaw.last, openers.contains(last), convert(markedRaw).last == last {
            let head = String(markedRaw.dropLast())
            if !head.isEmpty { commitMarked(client, convert(head), raw: head) }
            markedRaw = String(last)
            showMarked(client)
        } else {
            commitMarked(client, convert(markedRaw), raw: markedRaw)
            markedRaw = ""
        }
        return true
    }

    private func finishMarked(_ client: IMKTextInput?) {
        if !markedRaw.isEmpty {
            let full = (markedCommittedRaw + markedRaw).lowercased()
            commitMarked(client, english.contains(full) ? markedRaw : convert(markedRaw), raw: markedRaw)
            markedRaw = ""
        }
        markedCommittedRaw = ""
    }

    private func commitMarked(_ client: IMKTextInput?, _ text: String, raw: String) {
        client?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        markedCommittedRaw += raw
    }

    private func showMarked(_ client: IMKTextInput?) {
        let shown = convert(markedRaw)
        client?.setMarkedText(shown, selectionRange: NSRange(location: (shown as NSString).length, length: 0),
                              replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
