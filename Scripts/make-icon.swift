// Draws the app icon: a solid blue rounded square on the standard macOS icon grid.
// Usage: swift make-icon.swift <output.png>

import AppKit

let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
let canvas: CGFloat = 1024
// macOS icons sit in an 824pt square with ~185pt corners, inset from the 1024pt canvas.
let size: CGFloat = 824
let radius: CGFloat = 185

let output = URL(fileURLWithPath: CommandLine.arguments[1])

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let inset = (canvas - size) / 2
blue.setFill()
NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size, height: size), xRadius: radius, yRadius: radius).fill()
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: output)
