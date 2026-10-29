import Carbon
import Cocoa
import InputMethodKit

/// One per client text session: turns key events into engine keys and the engine's edits into client calls.
@objc(XattotInputController)
final class XattotInputController: IMKInputController {
    private static let lexicon = loadLexicon()

    private var session = HostSession(lexicon: XattotInputController.lexicon, store: DefaultsModeStore())
    /// Where the host left the caret, carried between events.
    private var caret = CaretTracker()

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let input = sender as? IMKTextInput,
              let key = KeyMapper.key(Self.facts(of: event)) else { return false }
        let client = IMKClient(input, caret: caret)
        if client.syncCaret() {
            session.endWord(client: client)
            _ = client.syncCaret()
        }
        let consumed = session.handle(key, client: client)
        if !consumed {
            // A passed character is typed from the ABC layout; any other key's effect is unknown.
            if case .character = key { client.passed(typing: event.characters) } else { client.passed(typing: nil) }
        }
        caret = client.caret
        return consumed
    }

    // Without the override the client keeps the last keyboard layout (often the Özbek one), so
    // passed keys go through its dead keys a second time and Chromium sees "Dead".
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        guard let input = sender as? IMKTextInput else { return }
        input.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
        let filter = [kTISPropertyInputSourceID as String: "com.apple.keylayout.ABC"] as CFDictionary
        if let abc = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first {
            TISSetInputMethodKeyboardLayoutOverride(abc)
        }
        caret = CaretTracker()
        let client = IMKClient(input, caret: caret)
        session.activate(bundleID: input.bundleIdentifier() ?? "", client: client)
        caret = client.caret
    }

    override func commitComposition(_ sender: Any!) {
        endWord(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        endWord(sender)
        super.deactivateServer(sender)
    }

    /// Ends the word at the client's current caret, so a moved caret fails any check instead of editing.
    private func endWord(_ sender: Any!) {
        guard let input = sender as? IMKTextInput else {
            session.reset()
            return
        }
        let client = IMKClient(input, caret: caret)
        _ = client.syncCaret()
        session.endWord(client: client)
        caret = client.caret
    }

    private static func facts(of event: NSEvent) -> KeyFacts {
        let flags = event.modifierFlags
        return KeyFacts(
            keyCode: event.keyCode,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            command: flags.contains(.command),
            control: flags.contains(.control),
            option: flags.contains(.option),
            // charactersIgnoringModifiers drops Caps Lock with Option, so it counts as Shift there.
            shift: flags.contains(.shift) || flags.contains(.capsLock))
    }

    private static func loadLexicon() -> any Lexicon {
        guard let resources = Bundle.main.resourceURL else {
            NSLog("Xattot: no resource folder, English guard off")
            return EmptyLexicon()
        }
        do {
            return try WordListLexicon.load(from: resources)
        } catch {
            NSLog("Xattot: word lists not loaded, English guard off: %@", String(describing: error))
            return EmptyLexicon()
        }
    }
}
