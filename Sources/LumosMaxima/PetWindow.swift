import AppKit
import SwiftUI

/// Windows that belong to no Space in particular, draw above normal windows, and never take focus.
final class FloatingPanel: NSPanel {
    init(size: NSSize, level: NSWindow.Level) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
    }

    // Borderless windows refuse key status by default; the pet needs clicks, never keys.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Mouse handling for the pet, in AppKit rather than SwiftUI.
///
/// A `DragGesture` in global coordinates fights the window it is moving: every `setFrameOrigin` shifts the
/// coordinate space the next translation is measured in, so the pet lags, jumps and can stall completely. AppKit
/// tracks the pointer in screen coordinates, so the window follows the cursor exactly.
/// The arithmetic of dragging a window, kept apart from AppKit so it can be tested without a pointer.
///
/// The pointer is tracked in screen coordinates and the grab point is remembered *inside the window*. Moving the
/// window to put that same point back under the pointer makes the window follow the cursor exactly, at any speed.
struct PetDrag {
    /// A press that never travels this far is a click, not a drag; 4 points is what AppKit itself uses.
    static let threshold: CGFloat = 4

    private let grabOffset: NSPoint
    private(set) var didDrag = false

    init(pointerInWindow: NSPoint) {
        grabOffset = pointerInWindow
    }

    /// Where the window should be for this pointer position, or nil while the movement is still a click.
    mutating func origin(forPointer pointerOnScreen: NSPoint, currentOrigin: NSPoint) -> NSPoint? {
        let proposed = NSPoint(x: pointerOnScreen.x - grabOffset.x, y: pointerOnScreen.y - grabOffset.y)
        guard didDrag || hypot(proposed.x - currentOrigin.x, proposed.y - currentOrigin.y) > Self.threshold else {
            return nil
        }
        didDrag = true
        return proposed
    }
}

final class PetInteractionView: NSView {
    enum Action {
        case click
        case doubleClick
        case moved
    }

    var onAction: ((Action) -> Void)?

    private var drag: PetDrag?
    /// A single click has to wait out the double-click interval, or the first click of a double click would open the
    /// quick strip just before Settings opens over it.
    private var pendingClick: DispatchWorkItem?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // The pet is a picture: nothing in it can take focus, and taking it would steal keystrokes from the front app.
    override var acceptsFirstResponder: Bool { false }

    override func mouseDragged(with event: NSEvent) {
        guard let window, var drag else { return }
        let pointerOnScreen = window.convertPoint(toScreen: event.locationInWindow)
        if let origin = drag.origin(forPointer: pointerOnScreen, currentOrigin: window.frame.origin) {
            window.setFrameOrigin(origin)
        }
        self.drag = drag
    }

    override func mouseUp(with event: NSEvent) {
        let dragged = drag?.didDrag ?? false
        drag = nil
        guard !dragged else {
            onAction?(.moved)
            return
        }
        // `clickCount` includes the click a double click ends, so the second one arrives as 2.
        if event.clickCount >= 2 {
            pendingClick?.cancel()
            pendingClick = nil
            onAction?(.doubleClick)
            return
        }
        let click = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingClick = nil
            self.onAction?(.click)
        }
        pendingClick = click
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: click)
    }

    /// A press that starts a drag must not leave a click waiting to fire.
    override func mouseDown(with event: NSEvent) {
        pendingClick?.cancel()
        pendingClick = nil
        drag = PetDrag(pointerInWindow: event.locationInWindow)
    }

    /// The window and its view are torn down together, so a click still waiting has nothing left to open.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            pendingClick?.cancel()
            pendingClick = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }
}

@MainActor
final class PetWindowController {
    static let padding: CGFloat = 2
    static let contentSize = NSSize(width: SunPetView.size + padding * 2, height: SunPetView.size + padding * 2)

    private let model: AppModel
    private var window: FloatingPanel?
    /// One click opens the short panel, a double click the full settings window.
    var onClick: (@MainActor (NSRect, NSScreen) -> Void)?
    var onDoubleClick: (@MainActor () -> Void)?

    init(model: AppModel) {
        self.model = model
    }

    var screen: NSScreen? { window?.screen ?? NSScreen.main }

    #if DEBUG
    func clickForDebug() {
        guard let frame, let screen else { return }
        onClick?(frame, screen)
    }

    func doubleClickForDebug() {
        onDoubleClick?()
    }

    /// Feeds the same arithmetic a real drag uses, so the end frame is what a person would see.
    func dragForDebug() -> String {
        guard let window else { return "no window" }
        let start = window.frame.origin
        var drag = PetDrag(pointerInWindow: NSPoint(x: 70, y: 70))
        var current = start
        for step in 1...15 {
            let pointer = NSPoint(x: start.x + 70 + CGFloat(step) * 8, y: start.y + 70 + CGFloat(step) * 4)
            if let next = drag.origin(forPointer: pointer, currentOrigin: current) {
                current = next
                window.setFrameOrigin(next)
            }
        }
        let moved = window.frame.origin
        print("pet drag: \(start) -> \(moved), moved \(drag.didDrag)")
        return "\(moved)"
    }
    #endif
    var frame: NSRect? { window?.frame }

    var isVisible: Bool { window?.isVisible ?? false }

    func setVisible(_ visible: Bool) {
        if visible { show() } else { hide() }
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        place(window)
        window.orderFrontRegardless()
        model.petVisible = true
    }

    func hide() {
        window?.orderOut(nil)
        model.petVisible = false
    }

    private func makeWindow() -> FloatingPanel {
        let window = FloatingPanel(size: Self.contentSize, level: .floating)
        let host = PetHostingView(rootView: PetRootView(model: model))
        host.frame = NSRect(origin: .zero, size: Self.contentSize)
        host.autoresizingMask = [.width, .height]

        let interaction = PetInteractionView(frame: NSRect(origin: .zero, size: Self.contentSize))
        interaction.autoresizingMask = [.width, .height]
        interaction.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .click:
                guard let frame = self.frame, let screen = self.screen else { return }
                self.onClick?(frame, screen)
            case .doubleClick:
                self.onDoubleClick?()
            case .moved:
                self.saveOrigin()
            }
        }
        host.addSubview(interaction)
        window.contentView = host
        return window
    }

    private func place(_ window: NSWindow) {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = Self.contentSize
        var origin = model.preferences.petOrigin
            ?? NSPoint(x: visible.maxX - size.width - 28, y: visible.minY + 24)
        // A display unplugged since the last drag must not strand the pet off screen.
        origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)
        origin.y = min(max(origin.y, visible.minY + 4), visible.maxY - size.height - 4)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func saveOrigin() {
        guard let window else { return }
        model.preferences.petOrigin = window.frame.origin
    }
}

// The app is usually not active, and without this the first click on the pet would only come to the window.
private final class PetHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The SwiftUI side of the pet window: just the sun. Clicks and drags are handled by `PetInteractionView` above.
struct PetRootView: View {
    let model: AppModel

    var body: some View {
        SunPetView(
            isAwake: model.isAwake,
            stage: SunStage.stage(for: model.sunHours),
            animates: model.petVisible && !ProcessInfo.processInfo.environment.keys.contains("LUMOS_PET_STILL")
        )
        .padding(PetWindowController.padding)
    }
}
