import AppKit
import PrismKit

/// The menu bar icon: the glyph for the chosen reading, a fill level, and optionally the number.
///
/// A template image, so the menu bar tints it like the system's own icons. Width is rounded to whole points: a
/// wobbling item shifts every icon to its left, and memory changes every few seconds.
@MainActor
enum VitalsIcon {
    static let height: CGFloat = 22
    private static let glyphWidth: CGFloat = 18
    private static let digitsGap: CGFloat = 3
    private static var font: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular) }

    static func image(reading: Reading, showsValue: Bool) -> NSImage {
        // The menu bar shows the same "119 GB" the panel does, minus the unit detail.
        let text = showsValue ? shortText(reading) : nil
        let textWidth = text.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) } ?? 0
        let width = textWidth > 0 ? glyphWidth + digitsGap + textWidth : glyphWidth
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            drawGlyph(reading: reading)
            if let text {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
                let size = (text as NSString).size(withAttributes: attributes)
                (text as NSString).draw(
                    at: NSPoint(x: glyphWidth + digitsGap, y: (height - size.height) / 2 + 0.5),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = reading.summary
        return image
    }

    /// "119 GB", or "62%" for the battery. Padded to a stable width by using a monospaced digit font.
    private static func shortText(_ reading: Reading) -> String {
        guard reading.kind != .battery else { return reading.value }
        return reading.value
    }

    private static func drawGlyph(reading: Reading) {
        let box = NSRect(x: 1, y: 4.5, width: 16, height: 13)
        let outline = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)
        outline.lineWidth = 1.3
        NSColor.black.setStroke()
        outline.stroke()

        // The bar is the used part: a nearly full drive looks nearly full at a glance.
        let inset = box.insetBy(dx: 2.2, dy: 2.2)
        let fill = NSRect(
            x: inset.minX,
            y: inset.minY,
            width: max(1, inset.width * reading.fraction),
            height: inset.height
        )
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inset, xRadius: 1.6, yRadius: 1.6).addClip()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 1.4, yRadius: 1.4).fill()
        NSGraphicsContext.restoreGraphicsState()

        // A small mark inside tells the three readings apart even at this size.
        NSColor.white.setFill()
        switch reading.kind {
        case .disk:
            break
        case .memory:
            let dot = NSRect(x: box.midX - 1.2, y: box.midY - 1.2, width: 2.4, height: 2.4)
            NSBezierPath(ovalIn: dot).fill()
        case .battery:
            let tip = NSRect(x: box.maxX + 0.6, y: box.midY - 2, width: 1.6, height: 4)
            NSBezierPath(roundedRect: tip, xRadius: 0.6, yRadius: 0.6).fill()
        }
    }
}
