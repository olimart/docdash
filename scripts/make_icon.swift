// Generates AppIcon.icns without any assets: draws a rounded-rect "D{}" glyph
// with CoreGraphics/AppKit and assembles the icns with iconutil.
// Usage: swift scripts/make_icon.swift <output.icns>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("DocDash-\(ProcessInfo.processInfo.processIdentifier).iconset")
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawIcon(size: Int, scale: Int, name: String) throws {
    let pixels = size * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let side = CGFloat(pixels)
    let inset = side * 0.05
    let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.18, yRadius: side * 0.18)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.35, blue: 0.85, alpha: 1),
        ending: NSColor(calibratedRed: 0.05, green: 0.15, blue: 0.45, alpha: 1)
    )!
    gradient.draw(in: path, angle: -90)

    let text = "D{}" as NSString
    let font = NSFont.systemFont(ofSize: side * 0.34, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
        at: NSPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2),
        withAttributes: attributes
    )

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: iconsetURL.appendingPathComponent(name))
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size, scale: 1, name: "icon_\(size)x\(size).png")
    try drawIcon(size: size, scale: 2, name: "icon_\(size)x\(size)@2x.png")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", output]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetURL)
guard process.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
print("wrote \(output)")
