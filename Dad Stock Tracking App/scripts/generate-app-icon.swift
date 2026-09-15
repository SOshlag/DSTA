import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Packaging/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func point(_ x: CGFloat, _ y: CGFloat, scale: CGFloat) -> NSPoint {
    NSPoint(x: x * scale, y: y * scale)
}

for (name, pixels) in outputs {
    let size = CGFloat(pixels)
    let scale = size / 1024
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Could not create icon bitmap") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let tile = NSBezierPath(
        roundedRect: NSRect(x: 82 * scale, y: 82 * scale, width: 860 * scale, height: 860 * scale),
        xRadius: 190 * scale,
        yRadius: 190 * scale
    )
    let gradient = NSGradient(
        starting: NSColor(red: 0.20, green: 0.47, blue: 0.94, alpha: 1),
        ending: NSColor(red: 0.08, green: 0.24, blue: 0.58, alpha: 1)
    )!
    gradient.draw(in: tile, angle: 90)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    tile.lineWidth = max(1, 12 * scale)
    tile.stroke()

    let axes = NSBezierPath()
    axes.move(to: point(276, 700, scale: scale))
    axes.line(to: point(276, 330, scale: scale))
    axes.line(to: point(758, 330, scale: scale))
    axes.lineWidth = max(1.5, 42 * scale)
    axes.lineCapStyle = .round
    axes.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.72).setStroke()
    axes.stroke()

    let graph = NSBezierPath()
    graph.move(to: point(322, 390, scale: scale))
    graph.line(to: point(430, 495, scale: scale))
    graph.line(to: point(526, 435, scale: scale))
    graph.line(to: point(682, 618, scale: scale))
    graph.line(to: point(754, 552, scale: scale))
    graph.lineWidth = max(2, 52 * scale)
    graph.lineCapStyle = .round
    graph.lineJoinStyle = .round
    NSColor.white.setStroke()
    graph.stroke()

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode icon PNG")
    }
    try data.write(to: iconset.appendingPathComponent(name))
}

func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    let value = value.bigEndian
    return withUnsafeBytes(of: value) { Array($0) }
}

let icnsRepresentations: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

var elements = Data()
for (type, filename) in icnsRepresentations {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    elements.append(type.data(using: .ascii)!)
    elements.append(contentsOf: bigEndianBytes(UInt32(png.count + 8)))
    elements.append(png)
}

var icns = Data("icns".utf8)
icns.append(contentsOf: bigEndianBytes(UInt32(elements.count + 8)))
icns.append(elements)
let icnsURL = root.appendingPathComponent("Packaging/AppIcon.icns")
try icns.write(to: icnsURL)

print(icnsURL.path)
