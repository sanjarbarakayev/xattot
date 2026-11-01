import AppKit

/// A small panel that captures the next key combination as the new shortcut.
final class ShortcutRecorder: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var monitor: Any?
    private var completion: ((Shortcut?) -> Void)?

    func record(completion: @escaping (Shortcut?) -> Void) {
        finish(nil)
        self.completion = completion

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 96),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Xattot shortcut"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        let label = NSTextField(
            wrappingLabelWithString:
                "Yangi kombinatsiyani bosing.\nKamida ⌃, ⌥ yoki ⌘ bölsin. Bekor qiliş uçun Esc.")
        label.alignment = .center
        label.frame = panel.contentView!.bounds.insetBy(dx: 20, dy: 18)
        label.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(label)
        self.panel = panel

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.finish(nil)
                return nil
            }
            let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: event.modifierFlags)
            if shortcut.isUsable {
                self.finish(shortcut)
            } else {
                NSSound.beep()
            }
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        finish(nil)
    }

    private func finish(_ shortcut: Shortcut?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        let completion = self.completion
        self.completion = nil
        let panel = self.panel
        self.panel = nil
        panel?.delegate = nil
        panel?.close()
        completion?(shortcut)
    }
}
