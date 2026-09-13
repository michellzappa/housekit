import CoreGraphics

/// One white mark on the house plate, in normalized field coordinates
/// (0…1 across the square field, origin bottom-left). The same glyph renders
/// on the 18pt menu bar plate and the 1024px app icon — see `MenuBarPlate`
/// and `IconPlate`.
public struct Mark: Sendable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// House alphas are 0.97 / 0.72 / 0.52 for a three-mark glyph.
    public var alpha: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.alpha = alpha
    }

    public var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

public struct Glyph: Sendable, Equatable {
    public var marks: [Mark]

    public init(_ marks: [Mark]) {
        self.marks = marks
    }

    /// The gap between marks, as a fraction of the field. 34/524 on the icon
    /// plate, which the menu bar plate snaps to half a point.
    public static let gap: CGFloat = 34 / 524

    /// `count` horizontal slabs stacked bottom-to-top; `alphas` bottom-first.
    public static func slabs(_ alphas: [CGFloat], insets: [CGFloat] = []) -> Glyph {
        let count = alphas.count
        let height = (1 - gap * CGFloat(count - 1)) / CGFloat(count)
        return Glyph(alphas.enumerated().map { index, alpha in
            let inset = index < insets.count ? insets[index] : 0
            return Mark(x: inset, y: CGFloat(index) * (height + gap), width: 1 - inset * 2, height: height, alpha: alpha)
        })
    }
}

/// The apps' glyphs, in one place so the family stays a family.
public enum HouseGlyphs {
    /// One tall left pane, two stacked right — the shape Tessellate makes.
    public static let tessellate: Glyph = {
        let gap = Glyph.gap
        let leftWidth = (1 - gap) / 2
        let rightX = leftWidth + gap
        let rightWidth = 1 - rightX
        let rightHeight = (1 - gap) / 2
        return Glyph([
            Mark(x: 0, y: 0, width: leftWidth, height: 1, alpha: 0.97),
            Mark(x: rightX, y: rightHeight + gap, width: rightWidth, height: rightHeight, alpha: 0.72),
            Mark(x: rightX, y: 0, width: rightWidth, height: rightHeight, alpha: 0.52)
        ])
    }()

    /// Three container slabs; the top one set down slightly narrower.
    public static let cargo = Glyph.slabs([0.97, 0.72, 0.52], insets: [0, 0, 62.0 / 524])

    /// Three sheets fanned diagonally, newest (front, bottom-right) brightest.
    public static let clip: Glyph = {
        let size: CGFloat = 0.66
        let step = (1 - size) / 2
        return Glyph([
            Mark(x: 0, y: step * 2, width: size, height: size, alpha: 0.52),
            Mark(x: step, y: step, width: size, height: size, alpha: 0.72),
            Mark(x: step * 2, y: 0, width: size, height: size, alpha: 0.97)
        ])
    }()

    public static let all: [String: Glyph] = [
        "tessellate": tessellate,
        "cargo": cargo,
        "clip": clip
    ]
}
