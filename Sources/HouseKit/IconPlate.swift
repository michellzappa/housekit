import AppKit

/// House app icon: Apple's 824-of-1024 rounded-square footprint with the same
/// plate and marks as the menu bar, scaled. Writes a complete `.iconset`.
public enum IconPlate {
    public static let canvas: CGFloat = 1024
    public static let frame = CGRect(x: 100, y: 100, width: 824, height: 824)
    public static let field = CGRect(x: 250, y: 250, width: 524, height: 524)
    public static let cornerRadius: CGFloat = 185
    public static let markRadius: CGFloat = 26

    public static let iconsetSizes: [(name: String, pixels: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    public static func bitmap(glyph: Glyph, pixels: Int) -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("could not create \(pixels)px bitmap")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        let ctx = graphicsContext.cgContext
        let scale = CGFloat(pixels) / canvas
        ctx.scaleBy(x: scale, y: scale)
        PlateStyle.draw(ctx, frame: frame, cornerRadius: cornerRadius, rimWidth: 4)
        for mark in glyph.marks {
            PlateStyle.fill(mark, in: field, cornerRadius: markRadius, snap: nil)
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    public static func png(glyph: Glyph, pixels: Int) -> Data {
        guard let data = bitmap(glyph: glyph, pixels: pixels).representation(using: .png, properties: [:]) else {
            fatalError("could not encode PNG")
        }
        return data
    }

    /// Writes every iconset size into `directory` (created if needed).
    public static func writeIconset(glyph: Glyph, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in iconsetSizes {
            try png(glyph: glyph, pixels: size.pixels).write(to: directory.appendingPathComponent(size.name))
        }
    }

    /// Writes the iconset next to `icnsURL` and runs `iconutil` to produce the `.icns`.
    public static func writeICNS(glyph: Glyph, to icnsURL: URL) throws {
        let iconset = icnsURL.deletingPathExtension().appendingPathExtension("iconset")
        try writeIconset(glyph: glyph, to: iconset)
        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
        try iconutil.run()
        iconutil.waitUntilExit()
        guard iconutil.terminationStatus == 0 else {
            throw NSError(domain: "HouseKit", code: Int(iconutil.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "iconutil failed for \(icnsURL.path)"
            ])
        }
        try FileManager.default.removeItem(at: iconset)
    }
}
