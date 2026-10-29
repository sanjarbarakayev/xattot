import Foundation

/// Reads a client's `markedRange()`. Some clients report "nothing marked" as an empty range
/// at the caret or at 0 instead of `NSNotFound`.
enum MarkedRange {
    static func shows(location: Int, length: Int) -> Bool {
        location != NSNotFound && length > 0
    }
}
