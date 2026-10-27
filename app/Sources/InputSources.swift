import Carbon

/// Thin wrapper over the Text Input Sources API.
enum InputSources {
    static let uzbekID = LayoutMode.digraph.sourceID
    static let changedNotification = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)

    static func currentID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return property(source, kTISPropertyInputSourceID)
    }

    static func enabledKeyboardSources() -> [SourceInfo] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        return sources(filter, includeAllInstalled: false).compactMap { source in
            guard let id: String = property(source, kTISPropertyInputSourceID) else { return nil }
            let ascii: Bool = property(source, kTISPropertyInputSourceIsASCIICapable) ?? false
            return SourceInfo(id: id, isASCIICapable: ascii)
        }
    }

    /// True while some app holds secure input, as password fields do. Says nothing about what is typed.
    static func secureInputActive() -> Bool {
        IsSecureEventInputEnabled()
    }

    static let enabledChangedNotification = Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)

    static func isInstalled(_ id: String) -> Bool {
        source(id) != nil
    }

    static func isEnabled(_ id: String) -> Bool {
        source(id).flatMap { property($0, kTISPropertyInputSourceIsEnabled) } ?? false
    }

    /// Asks to add the source to Input Sources. On macOS 26 the system first shows a
    /// consent prompt, so the result arrives later as enabledChangedNotification.
    static func requestEnable(_ id: String) {
        if let found = source(id) {
            TISEnableInputSource(found)
        }
    }

    static func requestDisable(_ id: String) {
        if let found = source(id) {
            TISDisableInputSource(found)
        }
    }

    @discardableResult
    static func select(_ id: String) -> Bool {
        guard let found = source(id) else { return false }
        return TISSelectInputSource(found) == noErr
    }

    private static func source(_ id: String) -> TISInputSource? {
        sources([kTISPropertyInputSourceID as String: id], includeAllInstalled: true).first
    }

    private static func sources(_ filter: [String: Any], includeAllInstalled: Bool) -> [TISInputSource] {
        let list = TISCreateInputSourceList(filter as CFDictionary, includeAllInstalled)?.takeRetainedValue()
        return (list as? [TISInputSource]) ?? []
    }

    private static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
    }
}
