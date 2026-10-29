import Foundation

/// Drives the engine against one text client at a time: applies its edits, verifies every
/// replacement before making it, and keeps the engine in the mode `AppModes` picks for the app.
struct HostSession {
    private var engine: Engine
    private var modes: AppModes
    /// Empty until the first activation.
    private var bundleID = ""

    var mode: Mode { engine.mode }

    init(lexicon: any Lexicon, store: any ModeStore) {
        engine = Engine(lexicon: lexicon)
        modes = AppModes(store: store)
    }

    /// Precondition: call `endWord(client:)` on the outgoing client first; activation drops the word.
    mutating func activate(bundleID: String, client: any TextClient) {
        self.bundleID = bundleID
        engine.reset()
        syncMode(client: client)
    }

    /// False exactly when the applied edits end in `.pass`: the app types the key itself.
    mutating func handle(_ key: Key, client: any TextClient) -> Bool {
        syncMode(client: client)
        return !apply(engine.handle(key), client: client)
    }

    /// A word boundary no key caused, such as a caret move or a commit request.
    mutating func endWord(client: any TextClient) {
        syncMode(client: client)
        _ = apply(engine.endWord(), client: client)
    }

    /// The client is gone: drop the word without editing anything.
    mutating func reset() {
        engine.reset()
    }

    /// Returns whether the last applied edit was `.pass`. `fallback` marks the list
    /// `replacementFailed()` returned, which never replaces.
    private mutating func apply(_ edits: [Edit], client: any TextClient, fallback: Bool = false) -> Bool {
        var passed = false
        for edit in edits {
            passed = false
            switch edit {
            case .pass:
                passed = true
            case .insert(let text):
                client.insert(text)
            case .setMarked(let text):
                client.setMarked(text)
            case .commit(let text):
                client.commit(text)
            case .replace(let expected, let text):
                // A replace in a fallback list has no recovery left, so it edits nothing.
                if fallback { continue }
                if !replace(expected: expected, with: text, client: client) {
                    passed = apply(engine.replacementFailed(), client: client, fallback: true)
                }
            }
        }
        return passed
    }

    /// The read before a replacement is the only read: right after one, Chromium still shows old text.
    private mutating func replace(expected: String, with text: String, client: any TextClient) -> Bool {
        let found = client.text(before: expected.count)
        if found == expected {
            client.replace(before: expected.count, with: text)
            return true
        }
        if let last = engine.lastReplacement {
            modes.observe(bundleID: bundleID, found: found, expected: last.expected, staleView: last.staleView)
        }
        return false
    }

    /// Runs before the engine sees the next key or boundary, so a flush from the switch always lands
    /// ahead of it. A mode learned mid-key therefore takes effect from the next key.
    private mutating func syncMode(client: any TextClient) {
        let target = modes.mode(for: bundleID)
        guard target != engine.mode else { return }
        _ = apply(engine.switchMode(target), client: client)
    }
}
