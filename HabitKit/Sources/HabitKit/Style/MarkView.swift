import SwiftUI

/// One day's mark, drawn in the current style. State is carried by shape alone.
public struct MarkView: View {
    public var state: DayState
    /// Today is an outline in the text colour around the day's mark.
    public var isToday: Bool
    /// A counted control under target shows a small plus, so it reads as "adds" before the tap.
    public var showsPlus: Bool
    public var size: CGFloat

    @Environment(\.style) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: DayState, isToday: Bool = false, showsPlus: Bool = false, size: CGFloat = 28) {
        self.state = state
        self.isToday = isToday
        self.showsPlus = showsPlus
        self.size = size
    }

    private var inset: CGFloat { size * 0.16 }
    private var inner: CGFloat { size - inset * 2 }

    public var body: some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(style.text, lineWidth: style.outlineWidth)
            }
            fill
                .frame(width: inner, height: inner)
                .transition(reduceMotion ? .identity : .drawIn)
            if showsPlus && state != .done {
                // A thin paper halo keeps the plus readable over hatching without hiding it.
                ZStack {
                    if state == .partDone {
                        PlusShape()
                            .stroke(style.paper, style: StrokeStyle(lineWidth: style.markLineWidth + 2.5, lineCap: .round))
                    }
                    PlusShape()
                        .stroke(style.text, style: StrokeStyle(lineWidth: style.markLineWidth, lineCap: .round))
                }
                .frame(width: size * 0.28, height: size * 0.28)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: state)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fill: some View {
        switch state {
        case .done:
            Rectangle().fill(style.mark)
        case .partDone:
            HatchShape(angle: style.tokens.hatchAngle, lines: style.tokens.hatchLines)
                .stroke(style.mark, lineWidth: style.markLineWidth)
                .overlay(Rectangle().strokeBorder(style.mark, lineWidth: style.markLineWidth * 0.66))
                .clipShape(Rectangle())
        case .loggedWhilePaused, .loggedOffSchedule:
            DiamondShape().fill(style.mark)
        case .paused:
            Capsule().fill(style.mark).frame(width: inner * 0.7, height: style.markLineWidth * 2)
        case .notLogged:
            Rectangle().strokeBorder(style.secondary, lineWidth: style.markLineWidth)
        case .offSchedule:
            // A small dot, so a day the habit is not set for never reads as a gap.
            Circle().fill(style.tertiary).frame(width: SmallMark.dotSize(cell: size), height: SmallMark.dotSize(cell: size))
        case .blank:
            // A future day shows its date alone.
            Color.clear
        }
    }
}

/// Five parallel lines at the style's hatch angle, rising to the right. It does not mirror in right-to-left.
struct HatchShape: Shape {
    var angle: Double
    var lines: Int

    func path(in rect: CGRect) -> Path {
        let radians = angle * .pi / 180
        let direction = CGPoint(x: cos(radians), y: -sin(radians))
        let normal = CGPoint(x: sin(radians), y: cos(radians))
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let projections = corners.map { $0.x * normal.x + $0.y * normal.y }
        let low = projections.min()!
        let high = projections.max()!
        let reach = hypot(rect.width, rect.height)
        var path = Path()
        for i in 1...lines {
            let t = low + (high - low) * CGFloat(i) / CGFloat(lines + 1)
            let centre = CGPoint(x: normal.x * t, y: normal.y * t)
            path.move(to: CGPoint(x: centre.x - direction.x * reach, y: centre.y - direction.y * reach))
            path.addLine(to: CGPoint(x: centre.x + direction.x * reach, y: centre.y + direction.y * reach))
        }
        return path
    }
}

/// The diamond with its cut, the same rule as the small marks.
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        SmallMark.cutDiamond(in: rect)
    }
}

struct PlusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// A mark draws in as one short stroke from the leading edge.
private struct DrawIn: ViewModifier {
    var progress: CGFloat
    func body(content: Content) -> some View {
        content.scaleEffect(x: max(progress, 0.001), y: 1, anchor: .leading)
    }
}

extension AnyTransition {
    static var drawIn: AnyTransition {
        .modifier(active: DrawIn(progress: 0), identity: DrawIn(progress: 1))
    }
}

#Preview("Marks") {
    let states: [DayState] = [.blank, .partDone, .done, .loggedOffSchedule, .paused]
    VStack(spacing: 16) {
        ForEach([Appearance.paper, .ink], id: \.self) { appearance in
            let style = ResolvedStyle(appearance: appearance)
            HStack(spacing: 12) {
                ForEach(states, id: \.self) { MarkView(state: $0, isToday: true) }
                MarkView(state: .blank, isToday: true, showsPlus: true)
                MarkView(state: .partDone, isToday: true, showsPlus: true)
            }
            .padding()
            .background(style.paper)
            .environment(\.style, style)
        }
    }
}
