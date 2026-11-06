import AppKit

let image = NSImage(size: NSSize(width: 720, height: 440))
image.lockFocus()
NSColor(srgbRed: 0.95, green: 0.96, blue: 0.98, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 720, height: 440).fill()
func text(
    _ text: String, _ x: Double, _ y: Double, _ size: Double, _ color: NSColor,
    _ weight: NSFont.Weight = .regular
) {
    (text as NSString).draw(
        at: NSPoint(x: x, y: y),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}
let primary = NSColor(srgbRed: 0.12, green: 0.16, blue: 0.22, alpha: 1)
let secondary = NSColor(srgbRed: 0.39, green: 0.44, blue: 0.51, alpha: 1)
text("菜单栏瘦身", 40, 358, 29, primary, .semibold)
text("MenuSlim 1.0.0 · macOS 27", 42, 328, 13, secondary)
let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 308, y: 220))
arrow.line(to: NSPoint(x: 408, y: 220))
arrow.move(to: NSPoint(x: 389, y: 239))
arrow.line(to: NSPoint(x: 408, y: 220))
arrow.line(to: NSPoint(x: 389, y: 201))
NSColor.systemBlue.setStroke()
arrow.stroke()
text("拖到右侧，完成安装", 245, 90, 22, primary, .medium)
text("Drag the app to Applications", 256, 64, 13, secondary)
text("安装后，请从「应用程序」打开", 40, 20, 11, secondary)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(
    to: URL(fileURLWithPath: CommandLine.arguments[1]))
