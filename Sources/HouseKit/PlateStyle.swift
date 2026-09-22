import AppKit

/// The house plate: dark diagonal gradient, hairline rim. Shared by the menu
/// bar and app icon renderers so the two never drift.
enum PlateStyle {
    static let gradientTop = NSColor(calibratedWhite: 0.28, alpha: 1)
    static let gradientBottom = NSColor(calibratedWhite: 0.13, alpha: 1)
    static let rim = NSColor(calibratedWhite: 1, alpha: 0.16)

    static func draw(_ ctx: CGContext, frame: CGRect, cornerRadius: CGFloat, rimWidth: CGFloat) {
        let path = NSBezierPath(roundedRect: frame, xRadius: cornerRadius, yRadius: cornerRadius)
        ctx.saveGState()
        path.addClip()
        let colors = [gradientTop.cgColor, gradientBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: frame.minX, y: frame.maxY),
                end: CGPoint(x: frame.maxX, y: frame.minY),
                options: []
            )
        }
        ctx.restoreGState()
        let rimPath = NSBezierPath(
            roundedRect: frame.insetBy(dx: rimWidth / 2, dy: rimWidth / 2),
            xRadius: cornerRadius - rimWidth / 2,
            yRadius: cornerRadius - rimWidth / 2
        )
        rimPath.lineWidth = rimWidth
        rim.setStroke()
        rimPath.stroke()
    }

    static func fill(_ mark: Mark, in field: CGRect, cornerRadius: CGFloat, snap: CGFloat?) {
        var rect = CGRect(
            x: field.minX + mark.x * field.width,
            y: field.minY + mark.y * field.height,
            width: mark.width * field.width,
            height: mark.height * field.height
        )
        if let snap {
            // Snap edges (not origin + size) so neighbouring marks keep their gap.
            let minX = (rect.minX * snap).rounded() / snap
            let minY = (rect.minY * snap).rounded() / snap
            let maxX = (rect.maxX * snap).rounded() / snap
            let maxY = (rect.maxY * snap).rounded() / snap
            rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        NSColor(calibratedWhite: 1, alpha: mark.alpha).setFill()
        switch mark.shape {
        case .roundedRect:
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        case .roundedTriangle:
            roundedTrianglePath(in: rect, radius: cornerRadius).fill()
        }
    }

    private static func roundedTrianglePath(in rect: CGRect, radius: CGFloat) -> NSBezierPath {
        let vertices = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        let radius = min(radius, min(rect.width, rect.height) * 0.18)
        let first = vertices[0]
        let next = vertices[1]
        let distance = tangentDistance(at: first, previous: vertices[2], next: next, radius: radius)
        let direction = next - first
        let start = first + direction * (distance / hypot(direction.x, direction.y))

        let path = CGMutablePath()
        path.move(to: start)
        path.addArc(tangent1End: vertices[1], tangent2End: vertices[2], radius: radius)
        path.addArc(tangent1End: vertices[2], tangent2End: vertices[0], radius: radius)
        path.addArc(tangent1End: vertices[0], tangent2End: vertices[1], radius: radius)
        path.closeSubpath()
        return NSBezierPath(cgPath: path)
    }

    private static func tangentDistance(
        at vertex: CGPoint,
        previous: CGPoint,
        next: CGPoint,
        radius: CGFloat
    ) -> CGFloat {
        let incoming = previous - vertex
        let outgoing = next - vertex
        let incomingLength = hypot(incoming.x, incoming.y)
        let outgoingLength = hypot(outgoing.x, outgoing.y)
        let angle = acos(
            max(-1, min(1, (incoming.x * outgoing.x + incoming.y * outgoing.y)
                / (incomingLength * outgoingLength)))
        )
        return min(radius / tan(angle / 2), min(incomingLength, outgoingLength) * 0.35)
    }
}

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
