import AppKit
import SwiftUI

/// Every icon Prism puts in the menu bar: an SF Symbol, optionally followed by a short number.
///
/// A template image, so the menu bar tints it like the system's own icons on a light, dark or tinted menu bar. The
/// width is rounded up to whole points: a fractional width makes every icon to its left shift as the number changes.
@MainActor
public enum MenuBarGlyph {
    public static let height: CGFloat = 22
    public static let defaultSymbolPointSize: CGFloat = 15.5
    private static let textGap: CGFloat = 4
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .medium)

    public static func image(
        symbol name: String,
        primaryLayerOnly: Bool = false,
        symbolPointSize: CGFloat = defaultSymbolPointSize,
        text: String?,
        accessibilityDescription: String
    ) -> NSImage {
        let symbol = symbolImage(name, primaryLayerOnly: primaryLayerOnly, pointSize: symbolPointSize)
        let symbolWidth = symbol.size.width.rounded(.up)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let text = text?.isEmpty == false ? text : nil
        let textSize = text.map { ($0 as NSString).size(withAttributes: attributes) } ?? .zero
        let width = text == nil ? symbolWidth : symbolWidth + textGap + textSize.width.rounded(.up)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            symbol.draw(in: NSRect(
                x: (symbolWidth - symbol.size.width) / 2,
                y: (height - symbol.size.height) / 2,
                width: symbol.size.width,
                height: symbol.size.height
            ))
            if let text {
                (text as NSString).draw(
                    at: NSPoint(x: symbolWidth + textGap, y: (height - textSize.height) / 2 + 0.5),
                    withAttributes: attributes
                )
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private static func symbolImage(_ name: String, primaryLayerOnly: Bool, pointSize: CGFloat) -> NSImage {
        // A clear layer still takes its space, so the icon keeps its width with or without it.
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: primaryLayerOnly ? [.black, .clear] : [.black]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            return NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).fill()
                return true
            }
        }
        return symbol
    }

    /// Hands back the previous image while nothing it draws has changed, so the shell skips the repaint.
    @MainActor
    public final class Cache {
        private var key: String?
        private var image: NSImage?

        public init() {}

        public func image(
            symbol: String,
            primaryLayerOnly: Bool = false,
            symbolPointSize: CGFloat = MenuBarGlyph.defaultSymbolPointSize,
            text: String?,
            accessibilityDescription: String
        ) -> NSImage {
            let key = "\(symbol)|\(primaryLayerOnly)|\(symbolPointSize)|\(text ?? "")|\(accessibilityDescription)"
            if key == self.key, let image { return image }
            let image = MenuBarGlyph.image(
                symbol: symbol,
                primaryLayerOnly: primaryLayerOnly,
                symbolPointSize: symbolPointSize,
                text: text,
                accessibilityDescription: accessibilityDescription
            )
            self.key = key
            self.image = image
            return image
        }
    }
}

public extension View {
    /// The SwiftUI side of `MenuBarGlyph`'s `primaryLayerOnly`, so a panel draws the same symbol as the menu bar.
    func symbolPrimaryLayerOnly(_ primaryLayerOnly: Bool, color: Color) -> some View {
        symbolRenderingMode(.palette)
            .foregroundStyle(color, primaryLayerOnly ? Color.clear : color)
    }
}
