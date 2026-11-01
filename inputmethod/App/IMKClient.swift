import Foundation
import InputMethodKit

/// `TextClient` over an IMK client for the length of one event. Reads and replacements use the
/// tracked caret: right after an edit, Chromium still reports the old selection.
final class IMKClient: TextClient {
    private let input: IMKTextInput
    private(set) var caret: CaretTracker
    /// The last verified read, whose exact UTF-16 range a replacement of the same length takes.
    private var lastRead: (caret: Int, characters: Int, units: Int)?

    init(_ input: IMKTextInput, caret: CaretTracker) {
        self.input = input
        self.caret = caret
    }

    /// Takes the client's selection as the caret; true when it moved from where the host left it.
    func syncCaret() -> Bool {
        caret.sync(to: input.selectedRange())
    }

    /// The app types a key the session passed.
    func passed(typing typed: String?) {
        caret.passed(typing: typed)
    }

    func text(before length: Int) -> String? {
        guard let location = caret.location,
            let found = UTF16Text.suffix(length, before: location, read: read)
        else { return nil }
        lastRead = (location, length, found.units)
        return found.text
    }

    func replace(before length: Int, with text: String) {
        guard let location = caret.location else { return }
        let units: Int
        if let last = lastRead, last.caret == location, last.characters == length {
            units = last.units
        } else if let found = UTF16Text.suffix(length, before: location, read: read) {
            units = found.units
        } else {
            return
        }
        lastRead = nil
        input.insertText(text, replacementRange: NSRange(location: location - units, length: units))
        caret.replace(units: units, with: text)
    }

    func insert(_ text: String) {
        input.insertText(text, replacementRange: Self.noRange)
        caret.insert(text)
    }

    func setMarked(_ text: String) {
        let end = NSRange(location: text.utf16.count, length: 0)
        input.setMarkedText(text, selectionRange: end, replacementRange: Self.noRange)
        caret.setMarked(text)
    }

    func commit(_ text: String) {
        input.insertText(text, replacementRange: Self.noRange)
        caret.insert(text)
    }

    private static let noRange = NSRange(location: NSNotFound, length: 0)

    private func read(_ range: NSRange) -> String? {
        input.attributedSubstring(from: range)?.string
    }
}
