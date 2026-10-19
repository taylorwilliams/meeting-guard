import AppKit

// Original clock mark, drawn from geometry. No third-party image assets.
let destination = CommandLine.arguments[1]
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 90, y: 90, width: 844, height: 844)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)
        NSGradient(starting: NSColor(srgbRed: 0.46, green: 0.62, blue: 1, alpha: 1), ending: NSColor(srgbRed: 0.24, green: 0.34, blue: 0.76, alpha: 1))!.draw(in: shape, angle: -65)
        NSColor.white.setStroke()
        let clock = NSBezierPath(ovalIn: NSRect(x: 275, y: 265, width: 474, height: 474))
        clock.lineWidth = 46; clock.stroke()
        let hands = NSBezierPath()
        hands.move(to: NSPoint(x: 512, y: 665)); hands.line(to: NSPoint(x: 512, y: 502)); hands.line(to: NSPoint(x: 620, y: 430))
        hands.lineWidth = 46; hands.lineCapStyle = .round; hands.lineJoinStyle = .round; hands.stroke()
        NSColor(srgbRed: 0.6, green: 1, blue: 0.85, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 701, y: 677, width: 122, height: 122)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", directory.path, "-o", destination]
try task.run(); task.waitUntilExit()
if task.terminationStatus != 0 { exit(task.terminationStatus) }
