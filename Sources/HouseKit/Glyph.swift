import CoreGraphics

public enum MarkShape: Sendable, Equatable {
    case roundedRect
    case roundedTriangle
}

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
    public var shape: MarkShape

    public init(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        alpha: CGFloat,
        shape: MarkShape = .roundedRect
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.alpha = alpha
        self.shape = shape
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

    /// A rounded play wedge: media moving home, rather than a generic stack.
    public static let cargo = Glyph([
        Mark(x: 0.15, y: 0.15, width: 0.70, height: 0.70, alpha: 0.94, shape: .roundedTriangle)
    ])

    /// Three sheets fanned diagonally, newest (front, bottom-right) brightest.
    public static let clip: Glyph = {
        let size: CGFloat = 0.60
        let step = (1 - size) / 2
        return Glyph([
            Mark(x: 0, y: step * 2, width: size, height: size, alpha: 0.40),
            Mark(x: step, y: step, width: size, height: size, alpha: 0.58),
            Mark(x: step * 2, y: 0, width: size, height: size, alpha: 0.84)
        ])
    }()

    /// Smaller, quieter version for Clip's 18pt menu-bar slot.
    public static let clipMenuBar: Glyph = {
        let size: CGFloat = 0.54
        let step = (1 - size) / 2
        return Glyph([
            Mark(x: 0, y: step * 2, width: size, height: size, alpha: 0.28),
            Mark(x: step, y: step, width: size, height: size, alpha: 0.45),
            Mark(x: step * 2, y: 0, width: size, height: size, alpha: 0.72)
        ])
    }()

    /// Three equal-width desk heights: one sit level, then two stand variants.
    public static let lift = Glyph([
        Mark(x: 0.10, y: 0.10, width: 0.80, height: 0.16, alpha: 0.40),
        Mark(x: 0.10, y: 0.42, width: 0.80, height: 0.16, alpha: 0.72),
        Mark(x: 0.10, y: 0.74, width: 0.80, height: 0.16, alpha: 0.72)
    ])

    /// A funnel of three centered slabs: many loose tabs on top, one sorted
    /// line at the bottom, brightest where it narrows.
    public static let sift = Glyph.slabs([0.97, 0.72, 0.52], insets: [0.33, 0.165, 0])

    /// A screen with two caption lines under it: the wide line brightest,
    /// the short centered line below it, the picture faint above.
    public static let subs: Glyph = {
        let gap = Glyph.gap
        let line: CGFloat = 0.14
        let pictureY = (line + gap) * 2
        return Glyph([
            Mark(x: 0, y: pictureY, width: 1, height: 1 - pictureY, alpha: 0.52),
            Mark(x: 0.08, y: line + gap, width: 0.84, height: line, alpha: 0.97),
            Mark(x: 0.22, y: 0, width: 0.56, height: line, alpha: 0.72)
        ])
    }()

    public static let all: [String: Glyph] = [
        "sift": sift,
        "lift": lift,
        "tessellate": tessellate,
        "cargo": cargo,
        "clip": clip,
        "subs": subs
    ]
}
