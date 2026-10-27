import AppKit

/// Menu bar icon in the style of the system input menu: a filled box when
/// Özbek is on, an outlined one when it is off. Template, so it follows the bar.
enum StatusIcon {
    static func image(on: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { bounds in
            IconArt.draw(
                square: bounds.insetBy(dx: 1.5, dy: 1), cornerRadius: 3.5,
                inkHeight: 10, filled: on, lineWidth: 1.2)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = on ? "Özbekça: yoqilgan" : "Özbekça: öçirilgan"
        return image
    }
}
