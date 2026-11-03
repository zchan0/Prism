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
    private static let digitsGap: CGFloat = 4
    private static let digitsFont = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)
    private static let symbolPointSize: CGFloat = 15.5

    /// A template image from an SF Symbol, so the menu bar tints it exactly like the icons Apple puts there, on a
    /// light, a dark or a wallpaper-tinted menu bar. The state is carried by shape:
    ///
    /// - `sun.min` while the Mac may sleep,
    /// - `sun.max` while it is kept awake but the screen may turn off,
    /// - `sun.max.fill` while the screen stays on too.
    ///
    /// Colour would read faster, but a coloured icon next to the system's monochrome ones looks pasted on.
    static func image(_ state: MenuBarState) -> NSImage {
        let text = state.timeText
        let textWidth = text.map { ($0 as NSString).size(withAttributes: [.font: digitsFont]).width.rounded(.up) } ?? 0
        let symbol = symbol(for: state)
        let symbolWidth = symbol.size.width.rounded(.up)
        let width = textWidth > 0 ? symbolWidth + digitsGap + textWidth : symbolWidth
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let symbolHeight = symbol.size.height
            symbol.draw(in: NSRect(
                x: 0,
                y: (height - symbolHeight) / 2,
                width: symbolWidth,
                height: symbolHeight
            ))
            if let text {
                let attributes: [NSAttributedString.Key: Any] = [.font: digitsFont, .foregroundColor: NSColor.black]
                let size = (text as NSString).size(withAttributes: attributes)
                (text as NSString).draw(
                    at: NSPoint(x: symbolWidth + digitsGap, y: (height - size.height) / 2 + 0.5),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = Strings.appName + ": " + state.accessibilityText
        return image
    }

    private static func symbol(for state: MenuBarState) -> NSImage {
        let name: String
        switch state.mode {
        case .asleep: name = "sun.min"
        case .forever, .counting: name = state.holdsDisplay ? "sun.max.fill" : "sun.max"
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.black]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            // No SF Symbols would mean no macOS, but an empty image would leave a hole in the menu bar.
            return NSImage(size: NSSize(width: symbolPointSize, height: symbolPointSize), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).fill()
                return true
            }
        }
        // A template drawn into a symbol already has the right alpha; this only makes sure the source is a template
        // too, so drawing it into another image keeps its shape instead of its colors.
        symbol.isTemplate = true
        return symbol
    }
}
