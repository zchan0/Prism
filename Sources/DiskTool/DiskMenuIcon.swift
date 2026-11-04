import AppKit
import PrismKit

/// The menu bar icon: a drive outline with a fill level, and optionally the free space next to it.
///
/// Text in the menu bar is a template too, so it is tinted exactly like the drive and reads on any background. The
/// width is rounded to whole points because a wobbling item shifts every icon to its left while the number counts up.
@MainActor
enum DiskMenuIcon {
    static let height: CGFloat = 22
    private static let glyphWidth: CGFloat = 17
    private static let digitsGap: CGFloat = 4
    private static var font: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular) }

    static func image(usage: DiskUsage, showsText: Bool) -> NSImage {
        let text = showsText ? ByteText.compact(usage.shownAvailable) : nil
        let textWidth = text.map { ($0 as NSString).size(withAttributes: [.font: font]).width.rounded() } ?? 0
        let width = textWidth > 0 ? glyphWidth + digitsGap + textWidth : glyphWidth
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            drawDrive(usedFraction: usage.usedFraction)
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
        image.accessibilityDescription = DiskStrings.freeOfTotal(
            ByteText.compact(usage.shownAvailable),
            ByteText.compact(usage.total)
        )
        return image
    }

    private static func drawDrive(usedFraction: Double) {
        let body = NSRect(x: 0.75, y: 5, width: 15.5, height: 12)
        let outline = NSBezierPath(roundedRect: body, xRadius: 3, yRadius: 3)
        outline.lineWidth = 1.3
        NSColor.black.setStroke()
        outline.stroke()

        // The fill is the used part, so a fuller drive looks fuller. It is clipped to the rounded body.
        let fill = NSRect(x: body.minX + 2, y: body.minY + 2, width: (body.width - 4) * usedFraction, height: body.height - 4)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: body.insetBy(dx: 1, dy: 1), xRadius: 2.4, yRadius: 2.4).addClip()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 1.6, yRadius: 1.6).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
