import Foundation

/// Maps the session's Character counts to the UTF-16 units an IMK client indexes its text by.
enum UTF16Text {
    struct Suffix: Equatable {
        let text: String
        /// The UTF-16 length of `text` as the client stores it: the range to replace.
        let units: Int
    }

    /// The most UTF-16 units read in one go; a longer run of Characters reports no text.
    static let maxWindow = 1024

    /// The last `count` Characters before `caret` (fewer near the start), read through `read`, which
    /// returns the client's text for a UTF-16 range. nil when a read fails, comes back at another
    /// length, or the Characters do not fit `maxWindow`.
    static func suffix(_ count: Int, before caret: Int, read: (NSRange) -> String?) -> Suffix? {
        guard count > 0, caret > 0 else { return Suffix(text: "", units: 0) }
        var window = min(caret, count * 2 + 2, maxWindow)
        while true {
            guard let text = read(NSRange(location: caret - window, length: window)),
                text.utf16.count == window
            else { return nil }
            let characters = Array(text)
            // The window may start inside a Character, so its first one only counts at the very start.
            if characters.count > count || window == caret {
                let tail = String(characters.suffix(count))
                return Suffix(text: tail, units: tail.utf16.count)
            }
            if window == maxWindow { return nil }
            window = min(caret, window * 2, maxWindow)
        }
    }
}

/// Where the caret should be after the host's own edits and the keys it passed, in UTF-16 units.
/// Unknown (nil) after a key whose effect the host cannot predict; the next report is then a baseline.
struct CaretTracker {
    private(set) var location: Int?
    /// The marked text, which always ends at the caret.
    private(set) var markedUnits = 0
    /// The caret before the host's edits of the last event: Chromium may still report it on the next key.
    private var beforeEdits: Int?

    /// Takes the client's selection at the start of an event as the caret. Returns whether it moved
    /// from where the host left it; a selection or `NSNotFound` leaves the caret unknown. `NSNotFound`
    /// is no move: a client that never reports a caret would otherwise end every marked word.
    /// A report still at the pre-edit caret is no move either, and the predicted caret stays: a real
    /// click there fails the verified check instead of editing.
    mutating func sync(to reported: NSRange) -> Bool {
        if let predicted = location, reported == NSRange(location: beforeEdits ?? -1, length: 0) {
            beforeEdits = predicted
            return false
        }
        let moved =
            reported.location != NSNotFound
            && location.map { NSRange(location: $0, length: 0) != reported } ?? false
        location = reported.location != NSNotFound && reported.length == 0 ? reported.location : nil
        beforeEdits = location
        return moved
    }

    /// Inserted or committed text, which replaces the marked text.
    mutating func insert(_ text: String) {
        location = location.map { $0 - markedUnits + text.utf16.count }
        markedUnits = 0
    }

    mutating func setMarked(_ text: String) {
        insert(text)
        markedUnits = text.utf16.count
    }

    mutating func replace(units: Int, with text: String) {
        location = location.map { $0 - units + text.utf16.count }
    }

    /// A key the app handles itself: `typed` is the text it inserts, nil when that is unknown.
    mutating func passed(typing typed: String?) {
        guard let typed, markedUnits == 0 else {
            location = nil
            return
        }
        location = location.map { $0 + typed.utf16.count }
    }
}
