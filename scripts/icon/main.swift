// Renders an .iconset with IconArt. Built by `make icon` together with app/Sources/IconArt.swift.
// Usage: icon <filled|outlined> <out.iconset>
//   filled   — the app icon: Ö knocked out of a solid rounded square
//   outlined — the input menu badge: outlined box with Ö, like the system "A" badge
import AppKit

let filled = CommandLine.arguments[1] == "filled"
let out = CommandLine.arguments[2]
let sizes: [(Int, String)] = [
    (16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]

for (px, name) in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let side = CGFloat(px)
    if filled {
        let square = CGRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88)
        IconArt.draw(square: square, cornerRadius: side * 0.2, inkHeight: side * 0.56, filled: true)
    } else {
        // Proportions of the system badges at 16 pt: ~1.2 pt stroke, ~3.5 pt corners, ~10 pt letter.
        // White: menu bar templates use only alpha, but the Globe switcher draws the same pixels
        // untinted on its dark panel and blue selection, where Apple's labels are white too.
        let stroke = side * 0.075
        let box = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: stroke / 2 + side * 0.03, dy: stroke / 2 + side * 0.03)
        IconArt.draw(
            square: box, cornerRadius: side * 0.22, inkHeight: side * 0.6, filled: false,
            lineWidth: stroke, color: .white)
    }

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
