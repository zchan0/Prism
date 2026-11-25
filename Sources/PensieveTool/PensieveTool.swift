import AppKit
import Carbon.HIToolbox
import Observation
import PrismKit
import SwiftUI
import UniformTypeIdentifiers

/// Pensieve has one shortcut, the one that opens the history.
enum ShortcutSlot: Hashable {
    case history
}

/// Why a shortcut was not taken. The tool keeps the shortcut it had.
enum ShortcutRefusal: Equatable, Sendable {
    case needsModifier
    case refusedBySystem
}

typealias HistoryShortcutRecorder = ShortcutRecorder<ShortcutSlot, ShortcutRefusal>

/// How long an item stays in the history after it was last copied.
enum HistoryAge: String, CaseIterable, Sendable {
    case day
    case week
    case month
    case threeMonths
    case never

    var interval: TimeInterval? {
        let day: TimeInterval = 24 * 60 * 60
        return switch self {
        case .day: day
        case .week: 7 * day
        case .month: 30 * day
        case .threeMonths: 90 * day
        case .never: nil
        }
    }
}

/// A history of what the person copies. A shortcut opens the list, and picking an item puts it back on the
/// clipboard, for the person to paste.
///
/// The clipboard has no change notification, so the tool compares its change count twice a second.
@MainActor
@Observable
public final class PensieveTool: Tool {
    public static let id = ToolID("pensieve")

    static let itemLimits = [50, 100, 200, 500, 1000]
    static let defaultItemLimit = 200
    static let defaultHistoryAge = HistoryAge.month
    /// The panel lists only the latest items; the history window has the rest.
    static let panelItemLimit = 10
    static let expiryCheckInterval: TimeInterval = 60 * 60
    static let maxBytes = 20 * 1024 * 1024
    static let defaultShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(shiftKey | cmdKey), keyName: "V")
    static let thumbnailPixels = 96
    /// The longest side of a picture's preview, in points.
    static let previewSide: CGFloat = 360

    /// Apps that show passwords, until the person changes the list.
    static var defaultIgnoredApps: [AppCandidate] {
        [
            ("com.apple.Passwords", "/System/Applications/Passwords.app", "Passwords"),
            // In Utilities until macOS 15.
            ("com.apple.keychainaccess", "/System/Library/CoreServices/Applications/Keychain Access.app", "Keychain Access"),
        ].map { bundleID, path, name in
            let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
            return AppCandidate(bundleID: bundleID, path: installed ?? path, name: name)
        }
    }

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Prism/Pensieve", directoryHint: .isDirectory)
    }

    private enum Key {
        static let paused = "paused"
        /// The shortcut as JSON, or an empty string once the person cleared it.
        static let shortcut = "shortcut"
        static let itemLimit = "maxItems"
        static let historyAge = "clearAfter"
        /// The apps as JSON. Missing until the person changes the list, which then stays as they left it, even empty.
        static let ignoredApps = "ignoredApps"
    }

    /// Newest first.
    private(set) var items: [ClipItem] = []
    private(set) var isPaused: Bool
    private(set) var shortcut: Shortcut?
    /// macOS refused the shortcut, when the tool started or when it was set.
    private(set) var shortcutFailed = false
    /// How many items the history keeps; a new one past it pushes out the oldest.
    private(set) var itemLimit: Int
    private(set) var historyAge: HistoryAge
    /// Copies made while one of these apps is in front are not recorded.
    private(set) var ignoredApps: [AppCandidate]

    @ObservationIgnored private let settings: ToolSettings
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored let store: HistoryStore
    @ObservationIgnored private let ticker: Ticking
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let frontmostBundleID: @MainActor () -> String?
    @ObservationIgnored let catalog = AppCatalog()
    @ObservationIgnored private var started = false
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var changeCount = 0
    @ObservationIgnored private var lastExpiryCheck: Date?
    /// While a shortcut is being recorded: otherwise pressing the current one opens the history instead.
    @ObservationIgnored private var shortcutsPaused = false
    @ObservationIgnored private(set) var registration: GlobalHotKey.Registration?
    @ObservationIgnored private var thumbnails: [UUID: NSImage] = [:]
    @ObservationIgnored private var fileIcons: [String: NSImage] = [:]
    @ObservationIgnored private let glyph = MenuBarGlyph.Cache()
    @ObservationIgnored private var historyWindow: HistoryWindowController?
    @ObservationIgnored private var shortcutRecorder: HistoryShortcutRecorder?
    @ObservationIgnored private var previewPanel: SidePanelController?
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var previewedID: UUID?
    #if DEBUG
    /// The items are samples for screenshots: the clipboard is not watched, nothing is read or saved, and the
    /// shortcut is not set up.
    @ObservationIgnored private var showsSamples = false
    @ObservationIgnored private var sampleImages: [UUID: Data] = [:]
    #endif

    public init(
        settings: ToolSettings = ToolSettings(tool: PensieveTool.id),
        pasteboard: NSPasteboard = .general,
        directory: URL = PensieveTool.defaultDirectory,
        ticker: Ticking = Ticker(),
        now: @escaping @MainActor () -> Date = { Date() },
        frontmostBundleID: @escaping @MainActor () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    ) {
        self.settings = settings
        self.pasteboard = pasteboard
        self.ticker = ticker
        self.now = now
        self.frontmostBundleID = frontmostBundleID
        store = HistoryStore(directory: directory)
        isPaused = settings.bool(Key.paused, default: false)
        shortcut = Self.decodeShortcut(settings.string(Key.shortcut, default: Self.encodeShortcut(Self.defaultShortcut)))
        let storedLimit = settings.plainInt(Key.itemLimit, default: Self.defaultItemLimit)
        itemLimit = Self.itemLimits.contains(storedLimit) ? storedLimit : Self.defaultItemLimit
        historyAge = HistoryAge(rawValue: settings.string(Key.historyAge, default: "")) ?? Self.defaultHistoryAge
        ignoredApps = Self.decodeIgnoredApps(settings.string(Key.ignoredApps, default: ""))
    }

    public var title: String { "Pensieve" }
    public var tagline: String { PensieveStrings.tagline }
    public var symbolName: String { "list.clipboard" }
    public var tint: ToolTint { Palette.pensieve }
    public var summary: String { isPaused ? PensieveStrings.paused : PensieveStrings.itemCount(items.count) }
    /// The panel is for picking an item; the settings hold the shortcut and the pause switch.
    public var showsControlsInWindow: Bool { false }

    /// What the panel lists.
    var panelItems: [ClipItem] {
        Array(items.prefix(Self.panelItemLimit))
    }

    public func start() {
        guard !started else { return }
        #if DEBUG
        if showsSamples { return }
        #endif
        started = true
        if !loaded {
            items = store.load()
            loaded = true
            dateUndatedItems()
        }
        trimToLimit()
        removeExpired()
        // What was on the clipboard before is not something the person copied while Pensieve was listening.
        changeCount = pasteboard.changeCount
        ticker.start(every: 0.5) { [weak self] in self?.tick() }
        registerShortcut()
        catalog.startWatching()
    }

    public func stop() {
        started = false
        ticker.stop()
        unregisterShortcut()
        shortcutFailed = false
        historyWindow?.close()
        hidePreview()
        catalog.stopWatching()
        // Also called as the app quits, when an item copied a moment ago may not be on disk yet.
        store.waitUntilSaved()
    }

    public func statusIcons() -> [StatusIcon] {
        [StatusIcon(id: "clipboard", image: glyph.image(
            symbol: symbolName,
            text: nil,
            accessibilityDescription: "\(title): \(summary)"
        ))]
    }

    public func controlsView() -> AnyView {
        AnyView(PensievePanelView(tool: self))
    }

    public func settingsView() -> AnyView? {
        AnyView(PensieveSettingsView(tool: self, recorder: recorder))
    }

    private func tick() {
        checkPasteboard()
        if let lastExpiryCheck, now().timeIntervalSince(lastExpiryCheck) >= Self.expiryCheckInterval {
            removeExpired()
        }
    }

    func checkPasteboard() {
        let count = pasteboard.changeCount
        guard count != changeCount else { return }
        changeCount = count
        guard !isPaused else { return }
        if let app = frontmostBundleID(), ignoredApps.contains(where: { $0.bundleID == app }) { return }
        capture()
    }

    private func capture() {
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else { return }
        let types = Set((pasteboard.types ?? []) + pasteboardItems.flatMap(\.types))
        guard types.isDisjoint(with: ClipTypes.skipped) else { return }
        var payload: Payload = []
        var byteCount = 0
        for pasteboardItem in pasteboardItems {
            var representations: [Representation] = []
            for type in pasteboardItem.types where ClipTypes.kept.contains(type) {
                guard let data = pasteboardItem.data(forType: type) else { continue }
                byteCount += data.count
                guard byteCount <= Self.maxBytes else { return }
                representations.append(Representation(type: type.rawValue, data: data))
            }
            if !representations.isEmpty {
                payload.append(representations)
            }
        }
        add(payload)
    }

    private func add(_ payload: Payload) {
        guard var item = ClipItem(id: UUID(), payload: payload) else { return }
        if let index = items.firstIndex(where: { $0.digest == item.digest }) {
            moveToFront(index)
            return
        }
        item.copiedAt = now()
        items.insert(item, at: 0)
        let dropped = Array(items.dropFirst(itemLimit))
        items.removeLast(dropped.count)
        for old in dropped {
            thumbnails[old.id] = nil
        }
        save(adding: (item.id, payload), removing: dropped.map(\.id))
    }

    /// Copying an item again counts as copying it now.
    private func moveToFront(_ index: Int) {
        var item = items.remove(at: index)
        item.copiedAt = now()
        items.insert(item, at: 0)
        save()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        #if DEBUG
        if showsSamples { return }
        #endif
        settings.set(paused, for: Key.paused)
    }

    /// The oldest items past the new limit go at once, with their data.
    func setItemLimit(_ limit: Int) {
        itemLimit = limit
        trimToLimit()
        #if DEBUG
        if showsSamples { return }
        #endif
        settings.setPlainInt(limit, for: Key.itemLimit)
    }

    func setHistoryAge(_ age: HistoryAge) {
        historyAge = age
        removeExpired()
        #if DEBUG
        if showsSamples { return }
        #endif
        settings.set(age.rawValue, for: Key.historyAge)
    }

    /// Refused when an app with the same bundle id is in the list already.
    @discardableResult
    func ignore(_ app: AppCandidate) -> Bool {
        guard !isIgnored(app) else { return false }
        ignoredApps.append(app)
        saveIgnoredApps()
        return true
    }

    func stopIgnoring(_ app: AppCandidate) {
        ignoredApps.removeAll { $0.id == app.id }
        saveIgnoredApps()
    }

    func isIgnored(_ app: AppCandidate) -> Bool {
        ignoredApps.contains { $0.bundleID == app.bundleID }
    }

    private func saveIgnoredApps() {
        #if DEBUG
        if showsSamples { return }
        #endif
        settings.set(Self.encodeIgnoredApps(ignoredApps), for: Key.ignoredApps)
    }

    /// Puts every representation the item had back on the clipboard, so a paste keeps its formatting.
    @discardableResult
    func copyToPasteboard(_ id: UUID) -> Bool {
        #if DEBUG
        if showsSamples { return false }
        #endif
        guard let index = items.firstIndex(where: { $0.id == id }), let payload = store.payload(of: id) else { return false }
        pasteboard.clearContents()
        let written = pasteboard.writeObjects(payload.map { representations in
            let pasteboardItem = NSPasteboardItem()
            for representation in representations {
                pasteboardItem.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
            }
            return pasteboardItem
        })
        // Seen already: reading it back would only find the same item.
        changeCount = pasteboard.changeCount
        moveToFront(index)
        return written
    }

    func remove(_ id: UUID) {
        drop([id])
    }

    func clear() {
        items = []
        thumbnails = [:]
        #if DEBUG
        if showsSamples { return }
        #endif
        store.removeAll()
    }

    private func drop(_ ids: Set<UUID>) {
        let dropped = items.filter { ids.contains($0.id) }.map(\.id)
        guard !dropped.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        for id in dropped {
            thumbnails[id] = nil
        }
        save(removing: dropped)
    }

    private func trimToLimit() {
        guard items.count > itemLimit else { return }
        drop(Set(items[itemLimit...].map(\.id)))
    }

    /// Run when the tool starts, every hour while it runs, and when the person picks another age.
    func removeExpired() {
        let checkedAt = now()
        lastExpiryCheck = checkedAt
        guard let interval = historyAge.interval else { return }
        let cutoff = checkedAt.addingTimeInterval(-interval)
        drop(Set(items.filter { ($0.copiedAt ?? checkedAt) < cutoff }.map(\.id)))
    }

    /// An index saved before items had a date: they count as copied now, so none expires at once.
    private func dateUndatedItems() {
        guard items.contains(where: { $0.copiedAt == nil }) else { return }
        let loadedAt = now()
        for index in items.indices where items[index].copiedAt == nil {
            items[index].copiedAt = loadedAt
        }
        save()
    }

    private func save(adding new: (id: UUID, payload: Payload)? = nil, removing removed: [UUID] = []) {
        #if DEBUG
        if showsSamples { return }
        #endif
        store.save(items, adding: new, removing: removed)
    }

    func cachedThumbnail(of id: UUID) -> NSImage? {
        thumbnails[id]
    }

    /// Made in the background from the saved image and kept in memory.
    func thumbnail(of item: ClipItem) async -> NSImage? {
        if let cached = thumbnails[item.id] { return cached }
        guard item.kind == .image else { return nil }
        guard let image = await image(of: item, maxPixelSize: Self.thumbnailPixels),
              items.contains(where: { $0.id == item.id }) else { return nil }
        thumbnails[item.id] = image
        return image
    }

    private func image(of item: ClipItem, maxPixelSize: Int) async -> NSImage? {
        #if DEBUG
        if showsSamples {
            guard let data = sampleImages[item.id] else { return nil }
            let image = await Task.detached { HistoryStore.thumbnail(of: data, maxPixelSize: maxPixelSize) }.value
            return image.map { NSImage(cgImage: $0, size: .zero) }
        }
        #endif
        let image = await withCheckedContinuation { continuation in
            store.thumbnail(of: item.id, maxPixelSize: maxPixelSize) { continuation.resume(returning: $0) }
        }
        return image.map { NSImage(cgImage: $0, size: .zero) }
    }

    /// A picture at up to `previewSide` points beside `window` after `delay`, top edges lined up. Anything else
    /// hides the preview.
    func showPreview(of item: ClipItem?, beside window: NSWindow, preferring side: SidePanelController.Side, after delay: Duration) {
        previewTask?.cancel()
        guard let item, item.kind == .image, let width = item.pixelWidth, let height = item.pixelHeight else {
            hidePreview()
            return
        }
        previewedID = item.id
        let scale = window.backingScaleFactor
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            let image = await image(of: item, maxPixelSize: Int((Self.previewSide * scale).rounded(.up)))
            guard !Task.isCancelled, let image,
                  let size = Self.previewSize(pixelWidth: width, pixelHeight: height, scale: scale) else { return }
            let panel = previewPanel ?? SidePanelController()
            previewPanel = panel
            panel.show(
                AnyView(ImagePreview(image: image, size: size, pixelWidth: width, pixelHeight: height)),
                beside: window,
                preferring: side
            )
        }
    }

    func hidePreview() {
        previewTask?.cancel()
        previewTask = nil
        previewedID = nil
        previewPanel?.hide()
    }

    /// Only while the preview is `id`'s: the pointer may enter the next row before it leaves this one.
    func hidePreview(of id: UUID) {
        guard previewedID == id else { return }
        hidePreview()
    }

    /// The picture's size at its own pixels, made smaller to fit in `previewSide` points but never larger.
    static func previewSize(pixelWidth: Int, pixelHeight: Int, scale: CGFloat) -> CGSize? {
        guard pixelWidth > 0, pixelHeight > 0, scale > 0 else { return nil }
        let width = CGFloat(pixelWidth) / scale
        let height = CGFloat(pixelHeight) / scale
        let factor = min(1, previewSide / width, previewSide / height)
        return CGSize(width: (width * factor).rounded(), height: (height * factor).rounded())
    }

    /// A file that is gone shows the icon of its kind.
    func icon(forFile path: String) -> NSImage {
        if let icon = fileIcons[path] { return icon }
        let icon = FileManager.default.fileExists(atPath: path)
            ? NSWorkspace.shared.icon(forFile: path)
            : NSWorkspace.shared.icon(for: UTType(filenameExtension: (path as NSString).pathExtension) ?? .data)
        fileIcons[path] = icon
        return icon
    }

    func toggleHistory() {
        if let historyWindow, historyWindow.isShown {
            historyWindow.close()
        } else {
            showHistory()
        }
    }

    func showHistory() {
        FloatingPanelController.hideAll()
        makeHistoryWindow().show()
    }

    private func makeHistoryWindow() -> HistoryWindowController {
        if let historyWindow { return historyWindow }
        let controller = HistoryWindowController(tool: self)
        historyWindow = controller
        return controller
    }

    private var recorder: HistoryShortcutRecorder {
        if let shortcutRecorder { return shortcutRecorder }
        let recorder = HistoryShortcutRecorder(
            setShortcut: { [weak self] shortcut, slot in self?.setShortcut(shortcut, for: slot) },
            pauseShortcuts: { [weak self] paused in self?.setShortcutsPaused(paused) }
        )
        shortcutRecorder = recorder
        return recorder
    }

    /// Nil when the tool has the shortcut now, or no shortcut when `shortcut` is nil.
    @discardableResult
    func setShortcut(_ shortcut: Shortcut?, for _: ShortcutSlot = .history) -> ShortcutRefusal? {
        if let shortcut {
            guard shortcut.hasRequiredModifier else { return .needsModifier }
            if started, shortcut != self.shortcut, !GlobalHotKey.canRegister(shortcut) {
                return .refusedBySystem
            }
        }
        self.shortcut = shortcut
        shortcutFailed = false
        #if DEBUG
        if showsSamples { return nil }
        #endif
        settings.set(shortcut.map(Self.encodeShortcut) ?? "", for: Key.shortcut)
        registerShortcut()
        return nil
    }

    func setShortcutsPaused(_ paused: Bool) {
        guard paused != shortcutsPaused else { return }
        shortcutsPaused = paused
        if paused {
            unregisterShortcut()
        } else {
            registerShortcut()
        }
    }

    private func registerShortcut() {
        unregisterShortcut()
        guard started, !shortcutsPaused, let shortcut else { return }
        let result = GlobalHotKey.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.toggleHistory()
        }
        switch result {
        case .success(let registration):
            self.registration = registration
            shortcutFailed = false
        case .failure:
            shortcutFailed = true
        }
    }

    private func unregisterShortcut() {
        if let registration {
            GlobalHotKey.unregister(registration)
        }
        registration = nil
    }

    private static func encodeShortcut(_ shortcut: Shortcut) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(shortcut) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// An empty string is a cleared shortcut; anything unreadable falls back to the default.
    private static func decodeShortcut(_ json: String) -> Shortcut? {
        guard !json.isEmpty else { return nil }
        return (try? JSONDecoder().decode(Shortcut.self, from: Data(json.utf8))) ?? defaultShortcut
    }

    private static func encodeIgnoredApps(_ apps: [AppCandidate]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(apps) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Nothing saved, or anything unreadable, is the default list.
    private static func decodeIgnoredApps(_ json: String) -> [AppCandidate] {
        (try? JSONDecoder().decode([AppCandidate].self, from: Data(json.utf8))) ?? defaultIgnoredApps
    }
}

#if DEBUG
extension PensieveTool {
    /// Lets go of the clipboard, the disk and the shortcut, and shows `samples` in place of the history. Called
    /// before `start()`, so the person's history is never read.
    func showSamplesForDebug(_ samples: [(item: ClipItem, thumbnail: NSImage?, image: Data?)]) {
        stop()
        showsSamples = true
        loaded = true
        items = samples.map(\.item)
        thumbnails = [:]
        sampleImages = [:]
        for sample in samples {
            thumbnails[sample.item.id] = sample.thumbnail
            sampleImages[sample.item.id] = sample.image
        }
    }

    /// The history window without showing it: showing it would take the keyboard.
    var historyWindowForDebug: HistoryWindowController {
        let controller = makeHistoryWindow()
        controller.prepareForDebug()
        return controller
    }

    var previewWindowForDebug: NSWindow? {
        previewPanel?.isShown == true ? previewPanel?.window : nil
    }
}
#endif
