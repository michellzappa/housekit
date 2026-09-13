import AppKit

/// House menu bar icon. 18pt canvas, 16pt plate, marks inside a 10pt field
/// (20px @2x). Drop-in for the `MenuBarPlate` files that used to be copied
/// between apps: the closure API is unchanged, and `image(glyph:)` renders the
/// same `Glyph` the app icon uses.
public enum MenuBarPlate {
    public static let canvas = NSSize(width: 18, height: 18)
    public static let frame = NSRect(x: 1, y: 1, width: 16, height: 16)
    public static let field = NSRect(x: 4, y: 4, width: 10, height: 10)
    public static let cornerRadius: CGFloat = 3.6
    public static let markRadius: CGFloat = 0.75

    @MainActor
    public static func image(glyph: Glyph) -> NSImage {
        image { _ in
            for mark in glyph.marks {
                PlateStyle.fill(mark, in: field, cornerRadius: markRadius, snap: 2)
            }
        }
    }

    @MainActor
    public static func image(marks: @escaping (CGContext) -> Void) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawPlate(ctx)
            marks(ctx)
            return true
        }
        image.isTemplate = false
        return image
    }

    public static func drawPlate(_ ctx: CGContext) {
        PlateStyle.draw(ctx, frame: frame, cornerRadius: cornerRadius, rimWidth: 0.5)
    }

    /// White mark with the shared corner radius, in points, snapped to @2x pixels.
    public static func mark(_ rect: NSRect, alpha: CGFloat) {
        let snapped = NSRect(
            x: (rect.minX * 2).rounded() / 2,
            y: (rect.minY * 2).rounded() / 2,
            width: (rect.width * 2).rounded() / 2,
            height: (rect.height * 2).rounded() / 2
        )
        NSColor(calibratedWhite: 1, alpha: alpha).setFill()
        NSBezierPath(roundedRect: snapped, xRadius: markRadius, yRadius: markRadius).fill()
    }
}
