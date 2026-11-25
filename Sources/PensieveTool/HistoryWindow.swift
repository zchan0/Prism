import AppKit
import Carbon.HIToolbox
import Observation
import PrismKit
import SwiftUI

/// What the history window shows and where its selection is. The window only calls into this.
@MainActor
@Observable
final class HistoryBrowser {
    var query = "" {
        didSet {
            if query != oldValue { selectedID = results.first?.id }
        }
    }
    var filter = ClipFilter.all {
        didSet {
            if filter != oldValue { selectedID = results.first?.id }
        }
    }
    private(set) var selectedID: UUID?
    /// Bumped on every opening, so the list starts at the top again.
    private(set) var opening = 0
    @ObservationIgnored private let tool: PensieveTool

    init(tool: PensieveTool) {
        self.tool = tool
    }

    var hasHistory: Bool { !tool.items.isEmpty }

    var results: [ClipItem] {
        tool.items.filter { filter.includes($0) && $0.matches(query) }
    }

    /// The row picked last while it is still in the results, or else the first one.
    var selection: ClipItem? {
        let results = results
        return results.first { $0.id == selectedID } ?? results.first
    }

    func reset() {
        query = ""
        filter = .all
        selectedID = results.first?.id
        opening += 1
    }

    func select(_ id: UUID) {
        selectedID = id
    }

    /// Tab goes to the next filter, ⇧Tab to the one before, round and round.
    func cycleFilter(by offset: Int) {
        filter = filter.cycled(by: offset)
    }

    /// Stops at the first and the last row.
    func move(by offset: Int) {
        let results = results
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selection?.id } ?? 0
        selectedID = results[min(max(current + offset, 0), results.count - 1)].id
    }

    /// The row that takes the removed one's place is selected, or the one above it at the end of the list.
    func removeSelection() {
        let before = results
        guard let index = before.firstIndex(where: { $0.id == selection?.id }) else { return }
        tool.remove(before[index].id)
        let after = results
        selectedID = after.isEmpty ? nil : after[min(index, after.count - 1)].id
    }

    func copySelection() -> Bool {
        guard let selection else { return false }
        return tool.copyToPasteboard(selection.id)
    }

    /// Clears the search first. True when there was nothing to clear, and the window should close.
    func escape() -> Bool {
        guard query.isEmpty else {
            query = ""
            return false
        }
        return true
    }
}

/// The keys the history window answers to; every other key goes to the search field.
enum HistoryKey: Equatable {
    case up
    case down
    case copy
    case remove
    case escape
    case nextFilter
    case previousFilter
    case settings

    init?(_ event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch (Int(event.keyCode), modifiers) {
        case (kVK_UpArrow, []): self = .up
        case (kVK_DownArrow, []): self = .down
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []): self = .copy
        case (kVK_Delete, .command): self = .remove
        case (kVK_Escape, []): self = .escape
        case (kVK_Tab, []): self = .nextFilter
        case (kVK_Tab, .shift): self = .previousFilter
        case (kVK_ANSI_Comma, .command): self = .settings
        default: return nil
        }
    }
}

/// Takes the keyboard without making Prism the active app, so the app the person was in stays in front and gets
/// the keyboard back when the window closes.
///
/// Titled, with its title bar hidden: with Liquid Glass, a borderless window that becomes key draws a dark rectangle
/// around its rounded corners. On macOS 26 its content sits on glass, and the window itself is clear.
final class HistoryPanel: NSPanel {
    var onKey: (@MainActor (NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    // Before the search field: it would take the arrows, Return and Esc for itself.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKey?(event) == true { return }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKey?(event) == true { return true }
        // Prism has no main menu, so nothing else sends the edit commands to the search field.
        let editActions: [String: Selector] = [
            "a": #selector(NSText.selectAll(_:)),
            "c": #selector(NSText.copy(_:)),
            "v": #selector(NSText.paste(_:)),
            "x": #selector(NSText.cut(_:)),
        ]
        if event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
           let action = editActions[event.charactersIgnoringModifiers?.lowercased() ?? ""],
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class HistoryWindowController {
    static let previewDelay: Duration = .milliseconds(150)

    let window: HistoryPanel
    private let browser: HistoryBrowser
    private let tool: PensieveTool
    private weak var searchField: NSTextField?
    private var resignObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?

    init(tool: PensieveTool) {
        let browser = HistoryBrowser(tool: tool)
        self.browser = browser
        self.tool = tool
        window = HistoryPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: HistoryView(
            browser: browser,
            tool: tool,
            choose: { [weak self] id in self?.choose(id) },
            selectionChanged: { [weak self] item in self?.selectionChanged(item) },
            searchFieldCreated: { [weak self] field in self?.searchField = field }
        ))
        hosting.sizingOptions = [.minSize, .maxSize]
        hosting.safeAreaRegions = []
        window.contentView = Self.background(for: hosting)
        if #available(macOS 26, *) {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.onKey = { [weak self] event in self?.handle(event) ?? false }
        window.updateConstraintsIfNeeded()
    }

    var isShown: Bool { window.isVisible }

    /// Glass on macOS 26, the window's own background before. The content is pinned to the glass on every edge, so
    /// the window still takes the content's size.
    private static func background(for content: NSView) -> NSView {
        guard #available(macOS 26, *) else { return content }
        let glass = NSGlassEffectView()
        glass.cornerRadius = 20
        glass.contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            content.topAnchor.constraint(equalTo: glass.topAnchor),
            content.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        return glass
    }

    /// In the middle of the screen with the pointer, with the search field ready for typing.
    func show() {
        browser.reset()
        window.contentView?.layoutSubtreeIfNeeded()
        let pointer = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        window.makeKeyAndOrderFront(nil)
        if let searchField {
            window.makeFirstResponder(searchField)
        }
        watchForLeaving()
        selectionChanged(browser.selection)
    }

    func close() {
        stopWatchingForLeaving()
        tool.hidePreview()
        guard window.isVisible else { return }
        window.orderOut(nil)
        // Now rather than at the next opening, so the window has its full size again by then.
        browser.reset()
    }

    /// A picture gets its preview beside the window a moment after it is selected, so moving through the list
    /// with the arrows does not flash one preview after another.
    private func selectionChanged(_ item: ClipItem?) {
        guard window.isVisible else { return }
        tool.showPreview(of: item, beside: window, preferring: .right, after: Self.previewDelay)
    }

    private func choose(_ id: UUID) {
        browser.select(id)
        if browser.copySelection() {
            close()
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let key = HistoryKey(event) else { return false }
        // While an input method is composing, the arrows, Return and Esc belong to it.
        if let editor = window.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        switch key {
        case .up:
            browser.move(by: -1)
        case .down:
            browser.move(by: 1)
        case .copy:
            if browser.copySelection() { close() }
        case .remove:
            browser.removeSelection()
        case .escape:
            if browser.escape() { close() }
        case .nextFilter:
            browser.cycleFilter(by: 1)
        case .previousFilter:
            browser.cycleFilter(by: -1)
        case .settings:
            close()
            tool.openPageInPrismWindow()
        }
        return true
    }

    /// Another app taking the keyboard, or a click outside the window, closes it.
    private func watchForLeaving() {
        if resignObserver == nil {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
        }
        if outsideClickMonitor == nil {
            // A global monitor only sees clicks sent to other apps. Mouse events need no permission.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.close() }
            }
        }
    }

    private func stopWatchingForLeaving() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    #if DEBUG
    func prepareForDebug() {
        browser.reset()
        window.contentView?.layoutSubtreeIfNeeded()
    }

    var filterForDebug: ClipFilter { browser.filter }
    #endif
}

/// A plain search field, in AppKit so the window can put the keyboard in it the moment it opens.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let created: @MainActor (NSTextField) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15)
        field.placeholderString = prompt
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        created(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}
