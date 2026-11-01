import Carbon

/// One system-wide shortcut via Carbon's RegisterEventHotKey, which needs no
/// Accessibility permission.
final class HotKey {
    var onPress: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x555A_4B42  // 'UZKB'

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().onPress()
                return noErr
            }, 1, &spec, context, &handlerRef)
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: HotKey.signature, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }
}
