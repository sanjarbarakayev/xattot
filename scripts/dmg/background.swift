// Renders the DMG window background: title, hint and an arrow from the app to Applications.
// Usage: background <out.png> <scale>. Geometry must match scripts/dmg/settings.py.
import AppKit

let out = CommandLine.arguments[1]
let scale = CGFloat(Double(CommandLine.arguments[2]) ?? 1)
let size = CGSize(width: 640, height: 400)
let iconRow: CGFloat = 175 // icon centre, measured from the top like Finder does

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(calibratedWhite: 0.965, alpha: 1).setFill()
CGRect(origin: .zero, size: size).fill()

func centered(_ text: String, size fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, top: CGFloat) {
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
    ])
    let bounds = string.size()
    string.draw(at: NSPoint(x: (size.width - bounds.width) / 2, y: size.height - top - bounds.height))
}

centered("Xattot", size: 22, weight: .bold, color: NSColor(calibratedWhite: 0.1, alpha: 1), top: 34)
centered("Ilovani Applications papkasiga sudrab taşlang", size: 13, weight: .regular,
         color: NSColor(calibratedWhite: 0.42, alpha: 1), top: 66)

let y = size.height - iconRow
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 250, y: y))
arrow.line(to: NSPoint(x: 384, y: y))
arrow.move(to: NSPoint(x: 370, y: y + 12))
arrow.line(to: NSPoint(x: 388, y: y))
arrow.line(to: NSPoint(x: 370, y: y - 12))
arrow.lineWidth = 3.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(calibratedWhite: 0.62, alpha: 1).setStroke()
arrow.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
