import AppKit

/// The Ö mark shared by the app icon, the layout icon and the menu bar item.
enum IconArt {
    /// Draws into the current graphics context. Filled: the letter is knocked out of a solid
    /// rounded square. Outlined: a stroked square with the letter drawn inside.
    static func draw(
        square: CGRect, cornerRadius: CGFloat, inkHeight: CGFloat, filled: Bool,
        lineWidth: CGFloat = 1, color: NSColor = .black
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let box = CGPath(roundedRect: square, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let glyph = centeredGlyph(in: square, inkHeight: inkHeight)

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        if filled {
            context.addPath(box)
            context.fillPath()
            context.setBlendMode(.destinationOut)
        } else {
            context.setLineWidth(lineWidth)
            context.addPath(box)
            context.strokePath()
        }
        context.addPath(glyph)
        context.fillPath()
        context.restoreGState()
    }

    /// The letter's outline, scaled to inkHeight and centred on its ink bounds (dots included),
    /// not on font metrics, which leave it sitting high.
    private static func centeredGlyph(in square: CGRect, inkHeight: CGFloat) -> CGPath {
        let outline = letterOutline()
        let bounds = outline.boundingBoxOfPath
        let scale = inkHeight / bounds.height
        var transform = CGAffineTransform(translationX: square.midX, y: square.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bounds.midX, y: -bounds.midY)
        return outline.copy(using: &transform) ?? outline
    }

    private static func letterOutline() -> CGPath {
        let font = CTFontCreateUIFontForLanguage(.system, 200, nil)!
        let bold = CTFontCreateCopyWithSymbolicTraits(font, 200, nil, .traitBold, .traitBold) ?? font
        var characters: [UniChar] = Array("Ö".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        CTFontGetGlyphsForCharacters(bold, &characters, &glyphs, characters.count)
        return CTFontCreatePathForGlyph(bold, glyphs[0], nil) ?? CGMutablePath()
    }
}
