import SwiftUI

/// The small shapes of the year view and the History month strip, drawn into one `Canvas`.
/// Part done is a triangle here and hatching in the larger marks, so the shape survives at a few points.
public enum SmallMark {
    /// The dot for a day not scheduled: 4 points, growing with the cell, never under 4.
    public static func dotSize(cell: CGFloat) -> CGFloat {
        max(4, (cell * 0.16).rounded())
    }

    /// The cut across a diamond, one rule at every size. Up to 12 points it is 2.5 units in 12 of the mark's width,
    /// so the small mark blurs apart from the done square (0.38, where a whole diamond is 0.16). Above 12 points it is
    /// a 1.25 point hairline, so a large diamond reads as one diamond, not two arrows. See `docs/m4-blur-test.md`.
    /// The small gap is close to the space between marks, so grouping rests on the shape.
    /// Re-run the neighbour blur check if the cut or the mark inset changes.
    public static func diamondCut(width: CGFloat) -> CGFloat {
        width <= 12 ? width * 2.5 / 12 : 1.25
    }

    /// A diamond filling `box` with a flat cut across its middle: two triangles, point up and point down.
    public static func cutDiamond(in box: CGRect) -> Path {
        let gap = diamondCut(width: box.width)
        // The diamond's half-width at the gap's edge.
        let halfWidth = box.width / 2 * (1 - gap / box.height)
        var path = Path()
        path.move(to: CGPoint(x: box.midX, y: box.minY))
        path.addLine(to: CGPoint(x: box.midX + halfWidth, y: box.midY - gap / 2))
        path.addLine(to: CGPoint(x: box.midX - halfWidth, y: box.midY - gap / 2))
        path.closeSubpath()
        path.move(to: CGPoint(x: box.midX - halfWidth, y: box.midY + gap / 2))
        path.addLine(to: CGPoint(x: box.midX + halfWidth, y: box.midY + gap / 2))
        path.addLine(to: CGPoint(x: box.midX, y: box.maxY))
        path.closeSubpath()
        return path
    }

    /// Draws one day into `rect`. `rect` is the cell; shapes sit inside it.
    public static func draw(_ state: DayState, isToday: Bool, in rect: CGRect, context: inout GraphicsContext, style: ResolvedStyle) {
        let cellSide = min(rect.width, rect.height)
        let cell = CGRect(x: rect.midX - cellSide / 2, y: rect.midY - cellSide / 2, width: cellSide, height: cellSide)
        // Today's outline is drawn inside the cell, so it never meets the next mark. It is heavier than the
        // not-logged square, and the mark fills the space just inside it, so the day's state stays readable.
        let todayWidth = style.outlineWidth * 1.2
        let box = isToday ? cell.insetBy(dx: todayWidth + 0.75, dy: todayWidth + 0.75) : cell
        let side = box.width
        let inner = isToday ? box : box.insetBy(dx: side * 0.12, dy: side * 0.12)
        let mark = GraphicsContext.Shading.color(style.mark)
        switch state {
        case .done:
            context.fill(Path(inner), with: mark)
        case .partDone:
            // Lower half, cut on the diagonal from the top leading corner.
            var path = Path()
            path.move(to: CGPoint(x: inner.minX, y: inner.minY))
            path.addLine(to: CGPoint(x: inner.minX, y: inner.maxY))
            path.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
            path.closeSubpath()
            context.fill(path, with: mark)
        case .paused:
            // As wide as the cell and thick enough to read, so a dash, a diamond and a dash never join.
            let height = max(2, side * 0.2)
            context.fill(Path(CGRect(x: inner.minX, y: box.midY - height / 2, width: inner.width, height: height)), with: mark)
        case .loggedWhilePaused, .loggedOffSchedule:
            context.fill(cutDiamond(in: box), with: mark)
        case .offSchedule:
            let d = dotSize(cell: side)
            context.fill(Path(ellipseIn: CGRect(x: box.midX - d / 2, y: box.midY - d / 2, width: d, height: d)), with: .color(style.tertiary))
        case .notLogged:
            context.stroke(Path(inner.insetBy(dx: 0.5, dy: 0.5)), with: .color(style.secondary), lineWidth: max(1, style.ruleWidth * 2))
        case .blank:
            break
        }
        if isToday {
            context.stroke(Path(cell.insetBy(dx: todayWidth / 2, dy: todayWidth / 2)), with: .color(style.text), lineWidth: todayWidth)
        }
    }
}
