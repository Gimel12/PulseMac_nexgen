import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let canvas = NSRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: canvas.insetBy(dx: 36, dy: 36), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1),
    NSColor(red: 0.18, green: 0.13, blue: 0.32, alpha: 1)
])!
gradient.draw(in: background, angle: -55)

let inner = NSBezierPath(roundedRect: canvas.insetBy(dx: 118, dy: 118), xRadius: 168, yRadius: 168)
NSColor.white.withAlphaComponent(0.055).setFill()
inner.fill()

let pulse = NSBezierPath()
pulse.move(to: NSPoint(x: 180, y: 500))
pulse.line(to: NSPoint(x: 330, y: 500))
pulse.line(to: NSPoint(x: 405, y: 650))
pulse.line(to: NSPoint(x: 505, y: 315))
pulse.line(to: NSPoint(x: 605, y: 575))
pulse.line(to: NSPoint(x: 680, y: 500))
pulse.line(to: NSPoint(x: 844, y: 500))
pulse.lineWidth = 52
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
NSColor(red: 0.36, green: 0.92, blue: 0.76, alpha: 1).setStroke()
pulse.stroke()

let dot = NSBezierPath(ovalIn: NSRect(x: 797, y: 453, width: 94, height: 94))
NSColor(red: 0.56, green: 0.45, blue: 1, alpha: 1).setFill()
dot.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
