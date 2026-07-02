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
    let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22)
    let gradient = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.33, green: 0.55, blue: 1.00, alpha: 1), 0.0),
        (NSColor(calibratedRed: 0.13, green: 0.30, blue: 0.86, alpha: 1), 0.55),
        (NSColor(calibratedRed: 0.06, green: 0.14, blue: 0.52, alpha: 1), 1.0)
    )!
    gradient.draw(in: path, angle: -90)

    // Single prominent "D" in SF Rounded, with a soft shadow for depth.
    let text = "D" as NSString
    let baseFont = NSFont.systemFont(ofSize: side * 0.62, weight: .bold)
    let font = baseFont.fontDescriptor.withDesign(.rounded)
        .flatMap { NSFont(descriptor: $0, size: side * 0.62) } ?? baseFont
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.015)
    shadow.shadowBlurRadius = side * 0.03
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .shadow: shadow,
    ]
    let textSize = text.size(withAttributes: attributes)
    text.draw(
        at: NSPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2 + side * 0.01),
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
