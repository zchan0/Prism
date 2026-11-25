import AppKit
import Observation
import PrismKit
import SwiftUI

enum WindowPage: Hashable {
    case tool(ToolID)
    /// Prism's own settings.
    case general
}

@MainActor
@Observable
final class PrismWindowModel {
    private(set) var page: WindowPage
    /// Bumped once a second while the window is open, so content that SwiftUI cannot observe is read again too.
    var revision = 0

    @ObservationIgnored private let toolIDs: [ToolID]

    init(toolIDs: [ToolID]) {
        self.toolIDs = toolIDs
        page = toolIDs.first.map(WindowPage.tool) ?? .general
    }

    /// An opening that names a page shows it; one that does not shows the page shown last.
    func open(on page: WindowPage?) {
        guard let page else { return }
        go(to: page)
    }

    func go(to page: WindowPage) {
        self.page = known(page)
    }

    private func known(_ page: WindowPage) -> WindowPage {
        if case .tool(let id) = page, !toolIDs.contains(id) { return .general }
        return page
    }
}

struct PrismWindowActions {
    var setEnabled: @MainActor (ToolID, Bool) -> Void
    var setPlacement: @MainActor (ToolID, MenuBarPlacement) -> Void
    var setAppearance: @MainActor (ShellSettings.Appearance) -> Void
    var quit: @MainActor () -> Void
}

/// The Prism window: every tool in a list on the left, and the chosen tool's page on the right, with its switch,
/// its settings and its menu bar settings. Prism's own settings are the last page.
@MainActor
final class PrismWindowController {
    static let contentSize = NSSize(width: 720, height: 600)

    var onSetEnabled: ((ToolID, Bool) -> Void)?
    var onSetPlacement: ((ToolID, MenuBarPlacement) -> Void)?
    var onSetAppearance: ((ShellSettings.Appearance) -> Void)?

    let window: NSWindow
    private let model: PrismWindowModel
    private let loginItem = LoginItem()
    private var hasBeenShown = false

    init(shell: ShellSettings, registrations: [ToolRegistration]) {
        let model = PrismWindowModel(toolIDs: registrations.map(\.id))
        self.model = model
        window = PrismWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let actions = PrismWindowActions(
            setEnabled: { [weak self] id, isOn in self?.onSetEnabled?(id, isOn) },
            setPlacement: { [weak self] id, placement in self?.onSetPlacement?(id, placement) },
            setAppearance: { [weak self] appearance in self?.onSetAppearance?(appearance) },
            quit: { NSApp.terminate(nil) }
        )
        let hosting = NSHostingView(rootView: PrismWindowView(
            model: model,
            shell: shell,
            registrations: registrations,
            loginItem: loginItem,
            actions: actions
        ))
        // Without this, SwiftUI keeps the content clear of the title bar.
        hosting.safeAreaRegions = []
        window.title = Strings.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // An empty toolbar only makes the title bar taller, which moves the close and minimize buttons in from the
        // list's corner.
        let toolbar = NSToolbar(identifier: "prism.window")
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.backgroundColor = Palette.window
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    /// Prism has no Dock icon, so the app is activated first; otherwise the window would open behind the app in front
    /// and never take the keyboard.
    func show(_ page: WindowPage?) {
        model.open(on: page)
        FloatingPanelController.hideAll()
        NSApp.activate()
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        window.makeKeyAndOrderFront(nil)
    }

    func refreshIfVisible() {
        guard window.isVisible else { return }
        model.revision += 1
    }

    #if DEBUG
    /// Turns to a page without activating Prism; the screenshot puts the window on screen.
    func prepareForCapture(_ page: WindowPage) {
        model.go(to: page)
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
    }
    #endif
}

// Prism has no main menu, so nothing else turns ⌘W into a close.
private final class PrismWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "w" else { return false }
        performClose(nil)
        return true
    }
}

private enum Metrics {
    static let sidebarWidth: CGFloat = 200
    static let sidebarMargin: CGFloat = 8
    /// Room for the window's close and minimize buttons, which sit on top of the list.
    static let titleBarClearance: CGFloat = 32
    static let pageSpacing: CGFloat = 16
}

struct PrismWindowView: View {
    let model: PrismWindowModel
    let shell: ShellSettings
    let registrations: [ToolRegistration]
    let loginItem: LoginItem
    let actions: PrismWindowActions

    var body: some View {
        let _ = model.revision
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: Metrics.sidebarWidth)
                .padding(Metrics.sidebarMargin)
            ZStack(alignment: .topLeading) {
                ScrollView {
                    page
                        .padding(.top, 22)
                        .padding(.leading, 14)
                        .padding(.trailing, 24)
                        .padding(.bottom, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(model.page)
                .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: PrismWindowController.contentSize.width, height: PrismWindowController.contentSize.height)
        .background(Color(nsColor: Palette.window))
    }

    private var sidebar: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 2) {
                Color.clear.frame(height: Metrics.titleBarClearance)
                PanelSectionTitle(Strings.tools)
                    .padding(.bottom, 4)
                ForEach(registrations, id: \.id) { registration in
                    let isOn = shell.isEnabled(registration.id)
                    SidebarRow(
                        tile: ToolTile(registration.tool, isOn: isOn, size: .small),
                        title: registration.tool.title,
                        status: isOn ? registration.tool.summary : Strings.off,
                        isSelected: model.page == .tool(registration.id)
                    ) {
                        go(.tool(registration.id))
                    }
                }
                Spacer(minLength: 12)
                SidebarRow(
                    tile: ToolTile(symbol: "gearshape", tint: Palette.neutral, size: .small),
                    title: Strings.general,
                    status: nil,
                    isSelected: model.page == .general
                ) {
                    go(.general)
                }
            }
            .padding(8)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var page: some View {
        switch model.page {
        case .tool(let id):
            if let registration = registrations.first(where: { $0.id == id }) {
                ToolPage(registration: registration, shell: shell, actions: actions)
            }
        case .general:
            GeneralPage(shell: shell, loginItem: loginItem, actions: actions)
        }
    }

    private func go(_ page: WindowPage) {
        withAnimation(.easeInOut(duration: 0.15)) {
            model.go(to: page)
        }
    }
}

private struct SidebarRow: View {
    let tile: ToolTile
    let title: String
    let status: String?
    let isSelected: Bool
    let select: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                tile
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(PanelFont.title)
                        .foregroundStyle(Color(nsColor: Palette.ink))
                    if let status {
                        Text(status)
                            .font(PanelFont.note)
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink3))
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: Color {
        if isSelected { return Color(nsColor: Palette.selection) }
        return hovered ? Color(nsColor: Palette.hover) : .clear
    }
}

/// The top of a page: the large tile, the name with a sentence under it, and a control on the right.
private struct PageHeader<Trailing: View>: View {
    let tile: ToolTile
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PanelFont.pageTitle)
                    .foregroundStyle(Color(nsColor: Palette.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(PanelFont.note)
                    .foregroundStyle(Color(nsColor: Palette.ink2))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 4)
    }
}

/// A tool's page: its switch, which is the only place that turns the tool on or off, then what the tool draws
/// itself, then its Menu Bar card.
private struct ToolPage: View {
    let registration: ToolRegistration
    let shell: ShellSettings
    let actions: PrismWindowActions

    var body: some View {
        let id = registration.id
        let tool = registration.tool
        let isOn = shell.isEnabled(id)
        VStack(alignment: .leading, spacing: Metrics.pageSpacing) {
            PageHeader(tile: ToolTile(tool, isOn: isOn, size: .large), title: tool.title, subtitle: tool.tagline) {
                PanelSwitch(
                    isOn: Binding(get: { shell.isEnabled(id) }, set: { actions.setEnabled(id, $0) }),
                    size: .large
                )
                .accessibilityLabel(tool.title)
            }
            if isOn {
                if tool.showsControlsInWindow {
                    tool.controlsView()
                }
                if let settings = tool.settingsView() {
                    settings
                }
                menuBarSection
            } else {
                PanelNote(Strings.turnedOffNote)
            }
        }
    }

    private var menuBarSection: some View {
        let id = registration.id
        let menuBar = registration.tool.menuBarSettings()
        return PanelSection(Strings.menuBar, note: menuBar?.note) {
            PanelRow(Strings.showInMenuBar) {
                PanelSwitch(isOn: Binding(
                    get: { shell.placement(of: id) == .ownIcon },
                    set: { actions.setPlacement(id, $0 ? .ownIcon : .hubOnly) }
                ))
            }
            if let menuBar {
                PanelDivider.inCard
                menuBar.rows
            }
        }
    }
}

/// Prism's own page.
private struct GeneralPage: View {
    let shell: ShellSettings
    let loginItem: LoginItem
    let actions: PrismWindowActions

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pageSpacing) {
            PageHeader(
                tile: ToolTile(symbol: "triangle", tint: Palette.neutral, size: .large),
                title: Strings.appName,
                subtitle: Strings.version(Self.version)
            ) {
                EmptyView()
            }
            PanelCard {
                PanelRow(Strings.appearance) {
                    PanelSegmented(
                        [
                            PanelSegmented.Item(ShellSettings.Appearance.system, title: Strings.appearanceSystem),
                            PanelSegmented.Item(.light, title: Strings.appearanceLight),
                            PanelSegmented.Item(.dark, title: Strings.appearanceDark),
                        ],
                        selection: shell.appearance,
                        select: actions.setAppearance
                    )
                    .frame(width: 240)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Strings.appearance)
                }
                PanelDivider.inCard
                PanelRow(Strings.loginItem, note: loginNote) {
                    PanelSwitch(isOn: Binding(
                        get: { loginItem.isOn },
                        set: { loginItem.setOn($0) }
                    ))
                    .disabled(!loginItem.isAvailable)
                }
                PanelDivider.inCard
                PanelRow(Strings.quit, note: Strings.quitNote) {
                    PanelButton(Strings.quitButton, action: actions.quit)
                }
            }
        }
        .onAppear { loginItem.refresh() }
    }

    private var loginNote: String? {
        if let error = loginItem.error { return error }
        return loginItem.status == .requiresApproval ? Strings.loginItemNeedsApproval : nil
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
