import Foundation

enum NamedKey: Equatable {
    case returnKey, enter, tab, escape, left, right, up, down, backspace
}

/// A key as the host reports it to `Engine.handle(_:)`.
/// - An Option key carries the character typed without Option, Shift applied (Shift+Option+s is `S`).
/// - Cmd or Ctrl combinations, a modified Backspace, forward delete, and Home/End/Page keys are `.shortcut`.
/// - A caret or focus change the engine did not cause is no key: the host calls `Engine.endWord()`,
///   or `Engine.reset()` when the client is gone.
enum Key: Equatable {
    case character(Character, option: Bool)
    case named(NamedKey)
    case shortcut
}

enum Mode: Equatable {
    case eager, marked
}
