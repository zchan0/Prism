import AppKit

/// What the menu bar shows: the state of the sun, and the countdown when the person asked for it.
struct MenuBarState: Equatable, Sendable {
    enum Mode: Equatable, Sendable {
        /// The Mac may sleep.
        case asleep
        /// Awake, with no timer set.
        case forever
        /// Awake, counting down.
        case counting(remaining: Int)

        var isAwake: Bool { self != .asleep }
    }

    var mode: Mode
    var showsTime: Bool
    var holdsDisplay: Bool

    var timeText: String? {
        guard showsTime, case .counting(let remaining) = mode else { return nil }
        return TimeText.compact(TimeInterval(remaining))
    }

    var accessibilityText: String {
        switch mode {
        case .asleep: Strings.sleeping
        case .forever: Strings.awake
        case .counting(let remaining): Strings.inTime(TimeText.remaining(TimeInterval(remaining)))
        }
    }
}

@MainActor
enum MenuBarIcon {
    static let height: CGFloat = 22
    // The disc lines up with menu bar text; rays fill the rest of the height.
    private static let discCenterX: CGFloat = 9.5
    private static let discRadius: CGFloat = 4.5
    private static let rayInner: CGFloat = 6.3
    private static let rayOuter: CGFloat = 9.0
    private static let rayWidth: CGFloat = 1.5
    private static let haloRadius: CGFloat = 2.0
    private static let digitsGap: CGFloat = 4.5
    private static let digitsFont = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)

    /// `appearance` is the status button's: the menu bar can be light or dark, and its label color has to resolve
    /// against that appearance rather than against the app's own.
    static func image(_ state: MenuBarState, appearance: NSAppearance? = nil) -> NSImage {
        let text = state.timeText
        let textWidth = text.map { ($0 as NSString).size(withAttributes: [.font: digitsFont]).width.rounded(.up) } ?? 0
        let width = textWidth > 0 ? discCenterX + rayOuter + digitsGap + textWidth : discCenterX + rayOuter + 1
        let warm = state.mode.isAwake
        let draw: () -> Void = {
            // The sleeping sun is a template; the awake one keeps its amber so the state reads without counting pixels.
            // Template images are tinted by the menu bar, so the ink here is only a placeholder.
            let ink = warm ? Palette.sun : NSColor.labelColor
            drawSun(ink: ink, warm: warm, holdsDisplay: state.holdsDisplay)
            if let text {
                let attributes: [NSAttributedString.Key: Any] = [.font: digitsFont, .foregroundColor: NSColor.labelColor]
                let size = (text as NSString).size(withAttributes: attributes)
                (text as NSString).draw(
                    at: NSPoint(x: discCenterX + rayOuter + digitsGap, y: (height - size.height) / 2 + 0.5),
                    withAttributes: attributes
                )
            }
        }
        let image: NSImage
        if warm {
            // Only the awake sun carries its own color, so only it needs the menu bar's appearance.
            image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
                if let appearance {
                    appearance.performAsCurrentDrawingAppearance(draw)
                } else {
                    draw()
                }
                return true
            }
            image.isTemplate = false
        } else {
            image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
                draw()
                return true
            }
            image.isTemplate = true
        }
        image.accessibilityDescription = Strings.appName + ": " + state.accessibilityText
        return image
    }

    private static func drawSun(ink: NSColor, warm: Bool, holdsDisplay: Bool) {
        let center = NSPoint(x: discCenterX, y: height / 2)
        ink.setStroke()
        ink.setFill()
        // A sleeping sun loses rays so it reads differently at a glance, not only by color.
        let rayCount = warm ? 8 : 5
        for index in 0..<rayCount {
            let angle = .pi * 2 * Double(index) / Double(rayCount) + (warm ? 0 : -.pi / 2)
            let start = NSPoint(x: center.x + cos(angle) * rayInner, y: center.y + sin(angle) * rayInner)
            let end = NSPoint(x: center.x + cos(angle) * rayOuter, y: center.y + sin(angle) * rayOuter)
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = rayWidth
            path.lineCapStyle = .round
            path.stroke()
        }
        NSBezierPath(ovalIn: NSRect(
            x: center.x - discRadius, y: center.y - discRadius,
            width: discRadius * 2, height: discRadius * 2
        )).fill()
        // A hollow core when the screen may still turn off; a solid disc when the screen stays on too.
        if !holdsDisplay {
            NSColor.clear.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: center.x - haloRadius, y: center.y - haloRadius,
                width: haloRadius * 2, height: haloRadius * 2
            )).fill()
        }
    }
}
