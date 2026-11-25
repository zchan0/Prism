#if DEBUG
import AppKit
import PrismKit

public enum PensieveDebug {
    /// For screenshots: puts sample items in place of the person's history, in memory only. Call it before the tool
    /// starts: from then on the clipboard is not watched, nothing is read or saved, and the shortcut is not set up.
    @MainActor
    public static func showSamples(_ tool: PensieveTool) {
        tool.showSamplesForDebug(samples())
    }

    /// The history window with the first row selected, built but not shown, and not centred yet.
    @MainActor
    public static func historyWindow(_ tool: PensieveTool) -> NSWindow {
        tool.historyWindowForDebug.window
    }

    /// Picks Images in the history window's filter menu, through the menu itself, while the window is on screen.
    /// `whileOpen` runs with the menu open. True when the menu opened and the window now lists only pictures.
    @MainActor
    public static func filterImagesThroughMenu(_ tool: PensieveTool, whileOpen: @escaping @MainActor () -> Void = {}) -> Bool {
        let controller = tool.historyWindowForDebug
        guard let index = ClipFilter.allCases.firstIndex(of: .images),
              PanelMenuButtonDebug.pick(index, in: controller.window, whileOpen: whileOpen) else { return false }
        return controller.filterForDebug == .images
    }

    /// The preview beside the history window, once a picture is selected.
    @MainActor
    public static func previewWindow(_ tool: PensieveTool) -> NSWindow? {
        tool.previewWindowForDebug
    }

    /// From the top: a color, a file, a picture, two lines of text, a link and a second picture.
    @MainActor
    static func samples() -> [(item: ClipItem, thumbnail: NSImage?, image: Data?)] {
        let sunset = sunsetImage()
        let peaks = peaksImage()
        let payloads: [Payload] = [
            [[text("#F05138")]],
            // A missing file shows the icon of its kind. Archive Utility opens zips on every Mac, so the icon is
            // never another app's.
            [[Representation(type: NSPasteboard.PasteboardType.fileURL.rawValue, data: URL(fileURLWithPath: "/Users/Shared/Trip Photos.zip").dataRepresentation)]],
            [[Representation(type: NSPasteboard.PasteboardType.png.rawValue, data: sunset)]],
            [[text("Lunch moved to Thursday at 12:30.\nI booked a table by the window for the four of us.")]],
            [[text("https://www.swift.org/documentation/")]],
            [[Representation(type: NSPasteboard.PasteboardType.png.rawValue, data: peaks)]],
        ]
        let now = Date()
        return payloads.enumerated().compactMap { index, payload in
            guard var item = ClipItem(id: UUID(), payload: payload) else { return nil }
            item.copiedAt = now.addingTimeInterval(-Double(index) * 600)
            let image = HistoryStore.imageData(in: payload)
            let thumbnail = image
                .flatMap { HistoryStore.thumbnail(of: $0, maxPixelSize: PensieveTool.thumbnailPixels) }
                .map { NSImage(cgImage: $0, size: .zero) }
            return (item, thumbnail, image)
        }
    }

    private static func text(_ string: String) -> Representation {
        Representation(type: NSPasteboard.PasteboardType.string.rawValue, data: Data(string.utf8))
    }

    /// A 1280 × 720 sunset, drawn rather than shipped.
    private static func sunsetImage() -> Data {
        drawing(width: 1280, height: 720) { bounds in
            NSGradient(colors: [
                NSColor(srgbRed: 0.98, green: 0.62, blue: 0.30, alpha: 1),
                NSColor(srgbRed: 0.93, green: 0.36, blue: 0.42, alpha: 1),
                NSColor(srgbRed: 0.36, green: 0.27, blue: 0.62, alpha: 1),
            ])?.draw(in: bounds, angle: 90)
            NSColor(srgbRed: 1, green: 0.86, blue: 0.55, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 520, y: 210, width: 240, height: 240)).fill()
            NSColor(srgbRed: 0.20, green: 0.16, blue: 0.36, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: 250)).fill()
        }
    }

    /// A 600 × 800 mountain range under a blue sky, standing up rather than lying down.
    private static func peaksImage() -> Data {
        drawing(width: 600, height: 800) { bounds in
            NSGradient(colors: [
                NSColor(srgbRed: 0.85, green: 0.93, blue: 0.98, alpha: 1),
                NSColor(srgbRed: 0.36, green: 0.62, blue: 0.90, alpha: 1),
            ])?.draw(in: bounds, angle: 90)
            let back = NSBezierPath()
            back.move(to: NSPoint(x: 0, y: 260))
            back.line(to: NSPoint(x: 210, y: 560))
            back.line(to: NSPoint(x: 360, y: 400))
            back.line(to: NSPoint(x: 470, y: 520))
            back.line(to: NSPoint(x: 600, y: 330))
            back.line(to: NSPoint(x: 600, y: 0))
            back.line(to: NSPoint(x: 0, y: 0))
            back.close()
            NSColor(srgbRed: 0.42, green: 0.50, blue: 0.66, alpha: 1).setFill()
            back.fill()
            let front = NSBezierPath()
            front.move(to: NSPoint(x: 0, y: 140))
            front.line(to: NSPoint(x: 160, y: 330))
            front.line(to: NSPoint(x: 330, y: 170))
            front.line(to: NSPoint(x: 600, y: 300))
            front.line(to: NSPoint(x: 600, y: 0))
            front.line(to: NSPoint(x: 0, y: 0))
            front.close()
            NSColor(srgbRed: 0.18, green: 0.36, blue: 0.30, alpha: 1).setFill()
            front.fill()
        }
    }

    private static func drawing(width: Int, height: Int, draw: (NSRect) -> Void) -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return Data() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        draw(NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }
}
#endif
