import AppKit
import Observation
import PrismKit
import SwiftUI

/// Why a shortcut was not given to an app. The app keeps the shortcut it had.
enum ShortcutRefusal: Equatable, Sendable {
    case usedBy(PortkeyApp)
    case needsModifier
    case refusedBySystem
}

typealias AppShortcutRecorder = ShortcutRecorder<UUID, ShortcutRefusal>

/// A global shortcut for each app the person adds, recorded on the tool's page in the Prism window.
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
    @ObservationIgnored private(set) var registrations: [UUID: GlobalHotKey.Registration] = [:]
    @ObservationIgnored let catalog = AppCatalog()
    @ObservationIgnored private let glyph = MenuBarGlyph.Cache()
    @ObservationIgnored private var shortcutRecorder: AppShortcutRecorder?
    #if DEBUG
    /// The apps are samples for screenshots: they are never saved, and their shortcuts are never set up.
    @ObservationIgnored private var showsSamples = false
    #endif

    public init(settings: ToolSettings = ToolSettings(tool: PortkeyTool.id)) {
        self.settings = settings
        apps = PortkeyApp.decodeList(settings.string(Key.apps, default: "[]"))
    }

    public var title: String { "Portkey" }
    public var tagline: String { PortkeyStrings.tagline }
    public var symbolName: String { "door.left.hand.open" }
    public var tint: ToolTint { Palette.portkey }
    public var summary: String { PortkeyStrings.appCount(apps.count) }
    /// The Apps card holds every app and shortcut the panel lists, and lets the person change them.
    public var showsControlsInWindow: Bool { false }

    public func start() {
        guard !started else { return }
        started = true
        reregister()
        catalog.startWatching()
    }

    public func stop() {
        started = false
        unregisterAll()
        failedAppIDs = []
        catalog.stopWatching()
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

    public func settingsView() -> AnyView? {
        AnyView(PortkeyAppsView(tool: self, recorder: recorder))
    }

    private var recorder: AppShortcutRecorder {
        if let shortcutRecorder { return shortcutRecorder }
        let recorder = AppShortcutRecorder(
            setShortcut: { [weak self] shortcut, id in self?.setShortcut(shortcut, for: id) },
            pauseShortcuts: { [weak self] paused in self?.setShortcutsPaused(paused) }
        )
        shortcutRecorder = recorder
        return recorder
    }

    /// What the app's shortcut does.
    func switchTo(_ app: PortkeyApp) {
        AppSwitcher.switchTo(app.target)
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
            if started, apps[index].shortcut != shortcut, !GlobalHotKey.canRegister(shortcut) {
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

    func displayName(of app: PortkeyApp) -> String {
        AppCatalog.displayName(path: app.path, savedName: app.name)
    }

    func icon(of app: PortkeyApp) -> NSImage {
        catalog.icon(atPath: app.path)
    }

    func isListed(_ candidate: AppCandidate) -> Bool {
        apps.contains { $0.isSameApp(as: candidate) }
    }

    private func appsChanged() {
        #if DEBUG
        if showsSamples { return }
        #endif
        settings.set(PortkeyApp.encodeList(apps), for: Key.apps)
        reregister()
    }

    private func reregister() {
        #if DEBUG
        if showsSamples { return }
        #endif
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
}

#if DEBUG
extension PortkeyTool {
    /// Lets go of every shortcut and shows `samples` in place of the person's apps. From then on nothing is saved and
    /// no shortcut is set up.
    func showSamplesForDebug(_ samples: [PortkeyApp]) {
        unregisterAll()
        failedAppIDs = []
        showsSamples = true
        apps = samples
    }
}
#endif
