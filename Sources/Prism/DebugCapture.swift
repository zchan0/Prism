#if DEBUG
import AppKit
import PrismKit
import VitalsTool

@MainActor
enum DebugCapture {
    /// Screenshots a window on screen. Glass is a window-server effect that `cacheDisplay` misses.
    static func window(_ window: NSWindow, to path: String) async -> Bool {
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1.2))
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        do {
            try capture.run()
        } catch {
            print("capture: \(error.localizedDescription)")
            return false
        }
        capture.waitUntilExit()
        return capture.terminationStatus == 0
    }

    /// Screenshots what is on screen around `frame`, at once, such as a window with a menu open on it.
    static func screen(around frame: NSRect, to path: String) -> Bool {
        guard let mainHeight = NSScreen.screens.first?.frame.height else { return false }
        let rect = frame.insetBy(dx: -24, dy: -24)
        // screencapture measures from the top left of the main display.
        let region = [rect.minX, mainHeight - rect.maxY, rect.width, rect.height].map { String(Int($0.rounded())) }
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-R", region.joined(separator: ","), path]
        // Not waitUntilExit, which would run the run loop from inside the menu's tracking.
        let exited = DispatchSemaphore(value: 0)
        capture.terminationHandler = { _ in exited.signal() }
        do {
            try capture.run()
        } catch {
            print("capture: \(error.localizedDescription)")
            return false
        }
        exited.wait()
        return capture.terminationStatus == 0
    }

    /// Every menu bar icon state, one 94x26 point cell each, on a light, a dark and a tinted menu bar, at 4x.
    static func statusIcons(to path: String) -> Bool {
        let icons: [NSImage] = [
            MenuBarGlyph.image(symbol: "wand.and.stars", primaryLayerOnly: true, text: nil, accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: "wand.and.stars", text: nil, accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: "wand.and.stars", text: "25m", accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: "cpu", text: CPUReading(user: 0.18, system: 0.05).reading.menuBarText, accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: Reading(kind: .memory, value: "", detail: "", fraction: 0).symbolName, text: "9.8 GB", accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: Reading(kind: .disk, value: "", detail: "", fraction: 0).symbolName, text: "119 GB", accessibilityDescription: ""),
            MenuBarGlyph.image(symbol: Reading(kind: .battery, value: "", detail: "", fraction: 0.62).symbolName, text: "62%", accessibilityDescription: ""),
        ]
        let rows: [(background: NSColor, ink: NSColor)] = [
            (NSColor(white: 0.92, alpha: 1), NSColor(white: 0, alpha: 0.85)),
            (NSColor(white: 0.165, alpha: 1), NSColor(white: 0.85, alpha: 1)),
            (NSColor(srgbRed: 0.16, green: 0.45, blue: 0.68, alpha: 1), NSColor(white: 0.85, alpha: 1)),
        ]
        let cell = NSSize(width: 94, height: 26)
        let scale: CGFloat = 4
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(cell.width * CGFloat(icons.count) * scale),
            pixelsHigh: Int(cell.height * CGFloat(rows.count) * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return false }
        bitmap.size = NSSize(width: cell.width * CGFloat(icons.count), height: cell.height * CGFloat(rows.count))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        for (rowIndex, row) in rows.enumerated() {
            let y = cell.height * CGFloat(rows.count - 1 - rowIndex)
            row.background.setFill()
            NSRect(x: 0, y: y, width: bitmap.size.width, height: cell.height).fill()
            for (column, icon) in icons.enumerated() {
                let tinted = NSImage(size: icon.size, flipped: false) { rect in
                    icon.draw(in: rect)
                    row.ink.setFill()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: NSRect(
                    x: cell.width * CGFloat(column) + (cell.width - icon.size.width) / 2,
                    y: y + (cell.height - icon.size.height) / 2,
                    width: icon.size.width,
                    height: icon.size.height
                ))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }
}
#endif
