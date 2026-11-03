#if DEBUG
import AppKit
import SwiftUI

/// Renders the real panel and pet through AppKit for the README images. ImageRenderer leaves AppKit-backed views
/// blank, so the views are hosted in a window and captured from the window's backing store.
@MainActor
enum DebugSnapshot {
    static func writePanel(to path: String, fixture: Bool, asleep: Bool = false) async -> Bool {
        if asleep {
            let content = PanelContent(
                isAwake: false,
                remaining: nil,
                length: .forever,
                elapsed: 0,
                keepsDisplayAwake: true,
                keepsAwakeWithLidClosed: false,
                lidBusy: false,
                battery: BatterySnapshot(hasBattery: true, level: 72, isCharging: false, isOnAC: false),
                lowBatteryThreshold: 20,
                sunHours: 1.2,
                petCount: 1,
                errorMessage: nil
            )
            return await renderPanel(content: content, to: path)
        }
        let content = PanelContent(
            isAwake: true,
            remaining: 24 * 60 + 12,
            length: .thirtyMinutes,
            elapsed: 5 * 60 + 48,
            keepsDisplayAwake: true,
            keepsAwakeWithLidClosed: false,
            lidBusy: false,
            battery: BatterySnapshot(hasBattery: true, level: 72, isCharging: false, isOnAC: false),
            lowBatteryThreshold: 20,
            sunHours: 3.4,
            petCount: 4,
            errorMessage: nil
        )
        return await renderPanel(content: content, to: path)
    }

    static func writePet(to path: String, awake: Bool) async -> Bool {
        let view = SunPetView(isAwake: awake, stage: .flare, remainingText: nil, animates: false, onToggle: {})
            .padding(PetWindowController.padding)
            .background(Color(nsColor: Palette.panelFill))
        return await render(view: view, size: PetWindowController.contentSize, to: path, transparent: false)
    }

    static func writeStatus(to path: String) -> Bool {
        let states: [MenuBarState] = [
            MenuBarState(mode: .asleep, showsTime: false, holdsDisplay: false),
            MenuBarState(mode: .asleep, showsTime: true, holdsDisplay: false),
            MenuBarState(mode: .forever, showsTime: true, holdsDisplay: true),
            MenuBarState(mode: .forever, showsTime: true, holdsDisplay: false),
            MenuBarState(mode: .counting(remaining: 25 * 60), showsTime: true, holdsDisplay: true),
            MenuBarState(mode: .counting(remaining: 2 * 3600 + 5 * 60), showsTime: true, holdsDisplay: false),
        ]
        let backgrounds: [(NSAppearance.Name, NSColor)] = [
            (.aqua, NSColor(white: 0.92, alpha: 1)),
            (.darkAqua, NSColor(white: 0.16, alpha: 1)),
            (.darkAqua, NSColor(srgbRed: 0.16, green: 0.45, blue: 0.68, alpha: 1)),
        ]
        let cell = NSSize(width: 94, height: 26)
        let size = NSSize(width: cell.width * CGFloat(states.count), height: cell.height * CGFloat(backgrounds.count))
        let scale = 4
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return false }
        bitmap.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        for (row, (appearanceName, fill)) in backgrounds.enumerated() {
            NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
                for (column, state) in states.enumerated() {
                    let origin = NSPoint(
                        x: CGFloat(column) * cell.width,
                        y: size.height - CGFloat(row + 1) * cell.height
                    )
                    fill.setFill()
                    NSRect(origin: origin, size: cell).fill()
                    let icon = MenuBarIcon.image(state)
                    drawAsMenuBar(icon, in: NSRect(
                        x: origin.x + (cell.width - icon.size.width) / 2,
                        y: origin.y + (cell.height - icon.size.height) / 2,
                        width: icon.size.width,
                        height: icon.size.height
                    ))
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("snapshot: status -> \(path)")
            return true
        } catch {
            print("snapshot: \(error.localizedDescription)")
            return false
        }
    }

    static func writeSettings(to path: String, settings: SettingsWindowController, tab: SettingsWindowController.Tab) async -> Bool {
        let window = settings.makeWindow(selecting: tab)
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1.2))
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        do {
            try capture.run()
        } catch {
            print("snapshot: \(error.localizedDescription)")
            return false
        }
        capture.waitUntilExit()
        return capture.terminationStatus == 0
    }

    static func capture(window: NSWindow?, to path: String) async -> Bool {
        guard let window, window.windowNumber > 0 else {
            print("snapshot: no panel window")
            return false
        }
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        do {
            try capture.run()
        } catch {
            print("snapshot: \(error.localizedDescription)")
            return false
        }
        capture.waitUntilExit()
        print("snapshot: panel window \(window.frame) exit \(capture.terminationStatus)")
        return capture.terminationStatus == 0
    }

    static func dump(model: AppModel) -> String {
        let state = model.menuBarState
        return [
            "awake: \(model.isAwake)",
            "mode: \(state.mode)",
            "remaining: \(model.remaining.map { TimeText.countdown($0) } ?? "none")",
            "assertion: \(model.engine.isHoldingDescription)",
            "lid: \(model.lid.status) byApp \(model.lid.enabledByApp)",
            "battery: \(model.battery.snapshot)",
            "sunHours: \(model.sunHours)",
        ].joined(separator: "\n")
    }

    private static func renderPanel(content: PanelContent, to path: String) async -> Bool {
        let actions = PanelActions(
            toggle: {},
            setLength: { _ in },
            setKeepsDisplayAwake: { _ in },
            setKeepsAwakeWithLidClosed: { _ in },
            confirmLidChange: {},
            showSettings: {},
            quit: {}
        )
        let view = PanelView(content: content, actions: actions, onHeightChange: { _ in })
        return await render(view: view, size: NSSize(width: PanelController.width, height: 420), to: path, transparent: false)
    }

    private static func render(view: some View, size: NSSize, to path: String, transparent: Bool) async -> Bool {
        let host = NSHostingView(rootView: view.background(transparent ? Color.clear : Color(nsColor: Palette.panelFill)))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = !transparent
        window.backgroundColor = .clear
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(0.8))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("snapshot: \(rep.pixelsWide)x\(rep.pixelsHigh) -> \(path)")
            return true
        } catch {
            print("snapshot: \(error.localizedDescription)")
            return false
        }
    }

    private static func drawAsMenuBar(_ image: NSImage, in rect: NSRect) {
        guard image.isTemplate else {
            image.draw(in: rect)
            return
        }
        let tinted = NSImage(size: image.size, flipped: false) { bounds in
            image.draw(in: bounds)
            NSColor.labelColor.set()
            bounds.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: rect)
    }
}
#endif
