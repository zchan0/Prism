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

/// SwiftUI's DragGesture reports a translation, not a window origin, so the origin is captured on the first move.
@MainActor
enum PetDragging {
    static var window: NSWindow?
    static var origin: NSPoint?
    static var onFinish: (() -> Void)?

    static func begin(_ window: NSWindow) {
        Self.window = window
        origin = window.frame.origin
    }

    static func finish() {
        window = nil
        origin = nil
        onFinish?()
    }
}

@MainActor
final class PetWindowController {
    static let padding: CGFloat = 2
    static let contentSize = NSSize(width: SunPetView.size + padding * 2, height: SunPetView.size + padding * 2)

    private let model: AppModel
    private var window: FloatingPanel?
    /// Clicking the sun opens the panel it shares with the menu bar item; the pet is a short cut to that, not a
    /// second set of controls.
    var onClick: (@MainActor (NSRect, NSScreen) -> Void)?

    init(model: AppModel) {
        self.model = model
    }

    var screen: NSScreen? { window?.screen ?? NSScreen.main }

    #if DEBUG
    func clickForDebug() {
        guard let frame, let screen else { return }
        onClick?(frame, screen)
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
        let host = PetHostingView(rootView: PetRootView(model: model) { [weak self] in
            guard let self, let frame = self.frame, let screen = self.screen else { return }
            self.onClick?(frame, screen)
        })
        host.frame = NSRect(origin: .zero, size: Self.contentSize)
        host.autoresizingMask = [.width, .height]
        window.contentView = host
        PetDragging.onFinish = { [weak self] in self?.saveOrigin() }
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

/// Hands the pet's window to PetDragging once, without the view having to know how it is hosted.
private struct WindowGrabber: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                PetDragging.begin(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The SwiftUI side of the pet window.
struct PetRootView: View {
    let model: AppModel
    let onClick: () -> Void

    var body: some View {
        SunPetView(
            isAwake: model.isAwake,
            stage: SunStage.stage(for: model.sunHours),
            remainingText: model.remaining.map { TimeText.remaining($0) },
            animates: model.petVisible && !ProcessInfo.processInfo.environment.keys.contains("LUMOS_PET_STILL"),
            onClick: onClick
        )
        .padding(PetWindowController.padding)
        // The hosting view's window is the pet window, and it is the one a drag moves.
        .background(WindowGrabber())
    }
}
