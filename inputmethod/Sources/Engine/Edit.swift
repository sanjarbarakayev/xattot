import Foundation

/// Applied in order. `.pass` is always last: the input method returns `false`
/// and the app types the key itself. A list holds at most one `.replace`.
enum Edit: Equatable {
    case pass
    /// Inserts the text at the caret; the key is consumed.
    case insert(String)
    /// Replaces exactly `expected`, the text immediately before the caret, only after reading it back
    /// to verify it. If it differs, the host replaces nothing, calls `Engine.replacementFailed()`
    /// and applies the edits it returns in place of this one.
    case replace(expected: String, with: String)
    /// Sets the marked text; `""` clears the marked range.
    case setMarked(String)
    /// Replaces the current marked range (or inserts at the caret if none) and ends composition.
    case commit(String)
}
