import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// An app a tool can list: one that is open, one in the Dock, or one the person picked in Applications. Tools store
/// it as JSON, so renaming a property loses the person's list.
public struct AppCandidate: Codable, Identifiable, Equatable, Sendable {
    public let bundleID: String
    public let path: String
    /// The name when it was added, shown when the app is no longer at `path`.
    public let name: String

    public var id: String { path }

    public init(bundleID: String, path: String, name: String) {
        self.bundleID = bundleID
        self.path = path
        self.name = name
    }

    /// The apps kept in the Dock, from the Dock's `persistent-apps` preference, in Dock order. An entry without a
    /// bundle id, or whose app is no longer where the Dock says, is left out.
    public static func dockApps(persistentApps: [Any], fileExists: (String) -> Bool) -> [AppCandidate] {
        var seenPaths = Set<String>()
        return persistentApps.compactMap { entry -> AppCandidate? in
            guard let tile = (entry as? [String: Any])?["tile-data"] as? [String: Any],
                  let bundleID = tile["bundle-identifier"] as? String, !bundleID.isEmpty,
                  let urlString = (tile["file-data"] as? [String: Any])?["_CFURLString"] as? String,
                  let path = filePath(urlString), fileExists(path),
                  seenPaths.insert(path).inserted else { return nil }
            let label = tile["file-label"] as? String ?? ""
            return AppCandidate(bundleID: bundleID, path: path, name: label.isEmpty ? appName(atPath: path) : label)
        }
    }

    private static func filePath(_ urlString: String) -> String? {
        if urlString.hasPrefix("/") { return URL(fileURLWithPath: urlString).path }
        guard let url = URL(string: urlString), url.isFileURL else { return nil }
        return url.path
    }

    private static func appName(atPath path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}

/// Where a tool's list of apps finds apps to add, and their names and icons.
///
/// While it watches, it follows apps opening and quitting, so the add menu lists the apps that are open now. The
/// Prism window's once-a-second redraw does not reach a tool's views: SwiftUI sees the same tool and skips them.
@MainActor
@Observable
public final class AppCatalog {
    private var runningAppsChanges = 0
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var icons: [String: NSImage] = [:]
    @ObservationIgnored private var menuIcons: [String: NSImage] = [:]

    public init() {}

    public func startWatching() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification]
            .map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.runningAppsChanges += 1 }
                }
            }
    }

    public func stopWatching() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers = []
    }

    /// The open apps, by name.
    public func openApps() -> [AppCandidate] {
        _ = runningAppsChanges
        var seenPaths = Set<String>()
        return NSWorkspace.shared.runningApplications
            .compactMap { running -> AppCandidate? in
                guard running.activationPolicy == .regular, !running.isTerminated,
                      let bundleID = running.bundleIdentifier, let url = running.bundleURL,
                      seenPaths.insert(url.path).inserted else { return nil }
                return AppCandidate(bundleID: bundleID, path: url.path, name: running.localizedName ?? Self.fileName(atPath: url.path))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The Dock's apps, in Dock order.
    public func dockApps() -> [AppCandidate] {
        let persistentApps = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") ?? []
        return AppCandidate.dockApps(persistentApps: persistentApps) { FileManager.default.fileExists(atPath: $0) }
    }

    /// The person picks apps in Applications, in a sheet on the window the menu was in.
    public func chooseApps(_ add: @escaping @MainActor (AppCandidate) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            let urls = panel.urls
            MainActor.assumeIsolated {
                for url in urls {
                    guard let bundleID = Bundle(url: url)?.bundleIdentifier else { continue }
                    add(AppCandidate(bundleID: bundleID, path: url.path, name: Self.fileName(atPath: url.path)))
                }
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    /// The app's name as Finder shows it, or the name it was added with once it is no longer at `path`.
    public func displayName(of app: AppCandidate) -> String {
        Self.displayName(path: app.path, savedName: app.name)
    }

    public static func displayName(path: String, savedName: String) -> String {
        FileManager.default.fileExists(atPath: path) ? fileName(atPath: path) : savedName
    }

    public func icon(atPath path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        guard FileManager.default.fileExists(atPath: path) else { return Self.genericIcon }
        // A symbolic link, such as /Applications/Safari.app, gets an icon with an alias arrow.
        let icon = NSWorkspace.shared.icon(forFile: URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
        icons[path] = icon
        return icon
    }

    /// A menu item draws its image at the image's own size.
    public func menuIcon(atPath path: String) -> NSImage {
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
}

public enum AppListMetrics {
    public static let rowHeight: CGFloat = 44
    public static let addRowHeight: CGFloat = 40
    public static let iconSize: CGFloat = 28
}

/// An app's icon at a fixed size.
public struct AppIconView: View {
    private let image: NSImage
    private let size: CGFloat

    public init(image: NSImage, size: CGFloat = AppListMetrics.iconSize) {
        self.image = image
        self.size = size
    }

    public var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// One app in a card that lists apps: its icon and name, a remove button that shows while the pointer is on the row,
/// then `accessory`. `message` goes under the row, such as why a shortcut was refused. A right-click offers
/// `menuItems`, then Remove.
public struct AppListRow<Accessory: View, MenuItems: View>: View {
    private let name: String
    private let icon: NSImage
    private let message: String?
    private let remove: @MainActor () -> Void
    private let accessory: Accessory
    private let menuItems: MenuItems
    @State private var hovered = false

    public init(
        name: String,
        icon: NSImage,
        message: String? = nil,
        remove: @escaping @MainActor () -> Void,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder menuItems: () -> MenuItems
    ) {
        self.name = name
        self.icon = icon
        self.message = message
        self.remove = remove
        self.accessory = accessory()
        self.menuItems = menuItems()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                AppIconView(image: icon)
                Text(name)
                    .font(PanelFont.title)
                    .foregroundStyle(Color(nsColor: Palette.ink))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                PanelIconButton(symbol: "minus", title: Strings.remove(name), isRevealed: hovered, action: remove)
                accessory
            }
            .frame(minHeight: AppListMetrics.rowHeight)
            if let message {
                Text(message)
                    .font(PanelFont.note)
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, AppListMetrics.iconSize + 10)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, PanelDivider.cardInset)
        .background(hovered ? Color(nsColor: Palette.hover) : .clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            menuItems
            Button(Strings.remove(name), action: remove)
        }
    }
}

public extension AppListRow where Accessory == EmptyView, MenuItems == EmptyView {
    init(name: String, icon: NSImage, remove: @escaping @MainActor () -> Void) {
        self.init(name: name, icon: icon, remove: remove, accessory: { EmptyView() }, menuItems: { EmptyView() })
    }
}

/// The last row of a card that lists apps: a menu of the apps that are open, the apps in the Dock, and any other app.
/// Apps for which `isListed` says yes are left out.
public struct AppAddMenu: View {
    private let catalog: AppCatalog
    private let isListed: @MainActor (AppCandidate) -> Bool
    private let add: @MainActor (AppCandidate) -> Void
    @State private var hovered = false

    public init(catalog: AppCatalog, isListed: @escaping @MainActor (AppCandidate) -> Bool, add: @escaping @MainActor (AppCandidate) -> Void) {
        self.catalog = catalog
        self.isListed = isListed
        self.add = add
    }

    public var body: some View {
        let open = catalog.openApps().filter { !isListed($0) }
        let dock = catalog.dockApps().filter { candidate in
            !isListed(candidate) && !open.contains { $0.bundleID == candidate.bundleID && $0.path == candidate.path }
        }
        Menu {
            if !open.isEmpty {
                Section(Strings.openApps) {
                    ForEach(open) { candidate in
                        item(candidate)
                    }
                }
            }
            if !dock.isEmpty {
                Section(Strings.dockApps) {
                    ForEach(dock) { candidate in
                        item(candidate)
                    }
                }
            }
            Divider()
            Button(Strings.otherApp) {
                catalog.chooseApps(add)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: AppListMetrics.iconSize, height: AppListMetrics.iconSize)
                Text(Strings.addApp)
                    .font(PanelFont.title)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(nsColor: Palette.ink2))
            .padding(.horizontal, PanelDivider.cardInset)
            .frame(maxWidth: .infinity, minHeight: AppListMetrics.addRowHeight, alignment: .leading)
            .background(hovered ? Color(nsColor: Palette.hover) : .clear)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onHover { hovered = $0 }
        .accessibilityLabel(Strings.addApp)
    }

    private func item(_ candidate: AppCandidate) -> some View {
        Button {
            add(candidate)
        } label: {
            Label {
                Text(candidate.name)
            } icon: {
                Image(nsImage: catalog.menuIcon(atPath: candidate.path))
            }
            .labelStyle(.titleAndIcon)
        }
    }
}
