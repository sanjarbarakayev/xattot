import Foundation

/// The focused text field as the session sees it. Lengths count Characters before the caret;
/// the input method's adapter maps them to the client's own units.
protocol TextClient: AnyObject {
    /// Up to `length` Characters immediately before the caret, fewer near the start; nil when the
    /// client exposes no text.
    func text(before length: Int) -> String?
    /// Replaces the `length` Characters immediately before the caret.
    func replace(before length: Int, with text: String)
    /// Inserts at the caret, replacing the marked range if there is one.
    func insert(_ text: String)
    /// Sets the marked range at the caret; `""` clears it.
    func setMarked(_ text: String)
    /// Replaces the marked range (or inserts at the caret) and ends composition.
    func commit(_ text: String)
}
