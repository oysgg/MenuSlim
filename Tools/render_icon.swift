import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()

    let tile = NSBezierPath(
        roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    NSGradient(colors: [
        NSColor(srgbRed: 0.08, green: 0.24, blue: 0.79, alpha: 1),
        NSColor(srgbRed: 0.12, green: 0.59, blue: 1, alpha: 1),
    ])!.draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // A compact row of menu items, with arrows drawing the outside space inward.
    NSColor.white.withAlphaComponent(0.18).setFill()
    NSBezierPath(roundedRect: NSRect(x: 178, y: 548, width: 668, height: 196), xRadius: 58, yRadius: 58)
        .fill()
    NSColor.white.setFill()
    for x in [304, 464, 624] {
        NSBezierPath(roundedRect: NSRect(x: x, y: 600, width: 96, height: 96), xRadius: 27, yRadius: 27)
            .fill()
    }
    let arrows = NSBezierPath()
    arrows.lineWidth = 30
    arrows.lineCapStyle = .round
    arrows.lineJoinStyle = .round
    arrows.move(to: NSPoint(x: 246, y: 354))
    arrows.line(to: NSPoint(x: 428, y: 354))
    arrows.move(to: NSPoint(x: 366, y: 416))
    arrows.line(to: NSPoint(x: 428, y: 354))
    arrows.line(to: NSPoint(x: 366, y: 292))
    arrows.move(to: NSPoint(x: 778, y: 354))
    arrows.line(to: NSPoint(x: 596, y: 354))
    arrows.move(to: NSPoint(x: 658, y: 416))
    arrows.line(to: NSPoint(x: 596, y: 354))
    arrows.line(to: NSPoint(x: 658, y: 292))
    NSColor.white.setStroke()
    arrows.stroke()
    NSColor(srgbRed: 0.55, green: 0.91, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 498, y: 302, width: 28, height: 104), xRadius: 14, yRadius: 14).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
