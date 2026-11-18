import AppKit
import Observation
import PrismKit
import SwiftUI
import UniformTypeIdentifiers

/// Why a shortcut was not given to an app. The app keeps the shortcut it had.
enum ShortcutRefusal: Equatable, Sendable {
    case usedBy(PortkeyApp)
    case needsModifier
    case refusedBySystem
}

/// A global shortcut for each app the person adds, recorded in the tool's window.
///
/// The shortcut brings the app to the front, opens it when it is not running, and hides it when it is in front already.
@MainActor
@Observable
public final class PortkeyTool: Tool {
    public static let id = ToolID("portkey")

    private enum Key {
        static let apps = "apps"
    }

    private let settings: ToolSettings
    private(set) var apps: [PortkeyApp]
    /// The apps whose shortcut macOS refused.
    private(set) var failedAppIDs: Set<UUID> = []
    private var started = false
    /// While a shortcut is being recorded: otherwise pressing a combination that is already set switches apps, and
    /// the window never sees the key.
    private var shortcutsPaused = false
    /// Bumped when an app opens or quits, so the add menu lists the apps that are open now.
    private var runningAppsChanges = 0
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var registrations: [UUID: GlobalHotKey.Registration] = [:]
    @ObservationIgnored private var icons: [String: NSImage] = [:]
    @ObservationIgnored private var menuIcons: [String: NSImage] = [:]
    @ObservationIgnored private let glyph = MenuBarGlyph.Cache()
    @ObservationIgnored private var windowController: ToolWindowController?

    public init(settings: ToolSettings = ToolSettings(tool: PortkeyTool.id)) {
        self.settings = settings
        apps = PortkeyApp.decodeList(settings.string(Key.apps, default: "[]"))
    }

    public var title: String { "Portkey" }
    public var symbolName: String { "door.left.hand.open" }
    public var summary: String { PortkeyStrings.appCount(apps.count) }

    public func start() {
        guard !started else { return }
        started = true
        reregister()
        watchRunningApps()
    }

    public func stop() {
        started = false
        unregisterAll()
        failedAppIDs = []
        stopWatchingRunningApps()
    }

    public func statusIcons() -> [StatusIcon] {
        // The door is taller than the other tools' symbols, and at their size it would stand above its neighbours.
        [StatusIcon(id: "door", image: glyph.image(
            symbol: symbolName,
            symbolPointSize: 13.5,
            text: nil,
            accessibilityDescription: "\(title): \(summary)"
        ))]
    }

    public func controlsView() -> AnyView {
        AnyView(PortkeyPanelView(tool: self))
    }

    public func settingsView() -> AnyView? { nil }

    func openWindow() {
        if windowController == nil {
            let recorder = ShortcutRecorder(tool: self)
            let controller = ToolWindowController(
                title: title,
                content: AnyView(PortkeyWindowView(tool: self, recorder: recorder))
            )
            recorder.window = controller.window
            windowController = controller
        }
        windowController?.show()
    }

    /// Refused when the app is in the list already. A new app has no shortcut until the person records one.
    @discardableResult
    func add(_ candidate: AppCandidate) -> Bool {
        guard !apps.contains(where: { $0.isSameApp(as: candidate) }) else { return false }
        apps.append(PortkeyApp(id: UUID(), bundleID: candidate.bundleID, path: candidate.path, name: candidate.name))
        appsChanged()
        return true
    }

    func remove(_ id: UUID) {
        apps.removeAll { $0.id == id }
        failedAppIDs.remove(id)
        appsChanged()
    }

    /// Nil when the app has the shortcut now, or no shortcut when `shortcut` is nil.
    @discardableResult
    func setShortcut(_ shortcut: Shortcut?, for id: UUID) -> ShortcutRefusal? {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return nil }
        if let shortcut {
            guard shortcut.hasRequiredModifier else { return .needsModifier }
            if let owner = apps.first(where: { $0.id != id && $0.shortcut == shortcut }) {
                return .usedBy(owner)
            }
            if started, apps[index].shortcut != shortcut, !Self.canRegister(shortcut) {
                return .refusedBySystem
            }
        }
        apps[index].shortcut = shortcut
        failedAppIDs.remove(id)
        appsChanged()
        return nil
    }

    func setShortcutsPaused(_ paused: Bool) {
        guard paused != shortcutsPaused else { return }
        shortcutsPaused = paused
        if paused {
            unregisterAll()
        } else {
            reregister()
        }
    }

    /// The open apps that are not in the list yet, by name.
    var openCandidates: [AppCandidate] {
        _ = runningAppsChanges
        var seenPaths = Set<String>()
        return NSWorkspace.shared.runningApplications
            .compactMap { running -> AppCandidate? in
                guard running.activationPolicy == .regular, !running.isTerminated,
                      let bundleID = running.bundleIdentifier, let url = running.bundleURL else { return nil }
                let candidate = AppCandidate(
                    bundleID: bundleID,
                    path: url.path,
                    name: running.localizedName ?? Self.fileName(atPath: url.path)
                )
                guard seenPaths.insert(candidate.path).inserted,
                      !apps.contains(where: { $0.isSameApp(as: candidate) }) else { return nil }
                return candidate
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The Dock's apps that are neither in the list nor open, in Dock order.
    func dockCandidates(excluding open: [AppCandidate]) -> [AppCandidate] {
        let persistentApps = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") ?? []
        return AppCandidate.dockApps(persistentApps: persistentApps) { FileManager.default.fileExists(atPath: $0) }
            .filter { candidate in
                !open.contains { $0.bundleID == candidate.bundleID && $0.path == candidate.path }
                    && !apps.contains { $0.isSameApp(as: candidate) }
            }
    }

    /// The person picks apps in Applications, in a sheet on the tool's window.
    func chooseApps() {
        guard let window = windowController?.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            MainActor.assumeIsolated {
                for url in urls {
                    guard let bundleID = Bundle(url: url)?.bundleIdentifier else { continue }
                    self?.add(AppCandidate(bundleID: bundleID, path: url.path, name: Self.fileName(atPath: url.path)))
                }
            }
        }
    }

    func displayName(of app: PortkeyApp) -> String {
        FileManager.default.fileExists(atPath: app.path) ? Self.fileName(atPath: app.path) : app.name
    }

    func icon(of app: PortkeyApp) -> NSImage {
        icon(atPath: app.path)
    }

    func icon(atPath path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        guard FileManager.default.fileExists(atPath: path) else { return Self.genericIcon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }

    /// A menu item draws its image at the image's own size.
    func menuIcon(atPath path: String) -> NSImage {
        if let icon = menuIcons[path] { return icon }
        let full = icon(atPath: path)
        let icon = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            full.draw(in: rect)
            return true
        }
        menuIcons[path] = icon
        return icon
    }

    private static let genericIcon = NSWorkspace.shared.icon(for: .application)

    private static func fileName(atPath path: String) -> String {
        let name = FileManager.default.displayName(atPath: path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// Whether macOS takes the combination now; it says no when this process holds it already.
    private static func canRegister(_ shortcut: Shortcut) -> Bool {
        switch GlobalHotKey.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: {}) {
        case .success(let registration):
            GlobalHotKey.unregister(registration)
            return true
        case .failure:
            return false
        }
    }

    private func appsChanged() {
        settings.set(PortkeyApp.encodeList(apps), for: Key.apps)
        reregister()
    }

    private func reregister() {
        guard started, !shortcutsPaused else { return }
        unregisterAll()
        var failed = Set<UUID>()
        for app in apps {
            guard let shortcut = app.shortcut else { continue }
            let target = app.target
            let result = GlobalHotKey.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) {
                AppSwitcher.switchTo(target)
            }
            switch result {
            case .success(let registration):
                registrations[app.id] = registration
            case .failure:
                failed.insert(app.id)
            }
        }
        failedAppIDs = failed
    }

    private func unregisterAll() {
        for registration in registrations.values {
            GlobalHotKey.unregister(registration)
        }
        registrations = [:]
    }

    // The hub's once-a-second redraw does not reach this tool's views: SwiftUI sees the same tool and skips them.
    private func watchRunningApps() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification]
            .map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.runningAppsChanges += 1 }
                }
            }
    }

    private func stopWatchingRunningApps() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers = []
    }
}
