import AppKit
import PrismKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let shell: ShellSettings
    private let registrations: [ToolRegistration]
    private let loginItem = LoginItem()
    private var window: NSWindow?

    init(shell: ShellSettings, registrations: [ToolRegistration]) {
        self.shell = shell
        self.registrations = registrations
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // An accessory app has to activate itself, or the window opens behind the frontmost app.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsRootView(
            shell: shell,
            registrations: registrations,
            loginItem: loginItem
        ))
        // A fixed height keeps the window from measuring its content: a grouped form with a tool section inside can
        // report an enormous preferred height and stretch the window into a column.
        hosting.sizingOptions = []
        let window = SettingsWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.title = Strings.appName
        window.contentMinSize = NSSize(width: SettingsRootView.width, height: 480)
        window.setContentSize(NSSize(width: SettingsRootView.width, height: SettingsRootView.height))
        window.onBecomeKey = { [loginItem] in loginItem.refresh() }
        window.center()
        return window
    }
}

/// One scrolling form: shell settings on top, then a section per tool.
///
/// A tool's section comes from its own `settingsView()`, and that view is plain content — no nested `Form`, no
/// `fixedSize` — so it lays out inside this form instead of trying to be a second window's worth of form.
struct SettingsRootView: View {
    static let width: CGFloat = 600
    static let height: CGFloat = 640

    let shell: ShellSettings
    let registrations: [ToolRegistration]
    let loginItem: LoginItem

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { loginItem.isOn }, set: { loginItem.setOn($0) })) {
                    Text(Strings.loginItem)
                    if let note = loginNote {
                        Text(note)
                    }
                }
                .disabled(!loginItem.isAvailable)
                LabeledContent(Strings.togglePanelShortcut) {
                    Text(verbatim: GlobalHotKey.keyName)
                }
            }

            Section {
                ForEach(registrations, id: \.id) { registration in
                    ToolSettingsRow(shell: shell, registration: registration)
                }
            } header: {
                Text(Strings.toolsSection)
            } footer: {
                Text(Strings.toolsFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(Strings.shortcuts) {
                Text(Strings.hubMenuBarNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: Self.width, height: Self.height)
    }

    private var loginNote: String? {
        if let error = loginItem.error { return error }
        return loginItem.status == .requiresApproval ? Strings.loginItemNeedsApproval : nil
    }
}

/// One tool in Settings: whether it runs, where it shows, and whatever it configures itself.
private struct ToolSettingsRow: View {
    let shell: ShellSettings
    let registration: ToolRegistration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: registration.tool.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(registration.tool.title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { shell.isEnabled(registration.id) },
                    set: { shell.setEnabled($0, for: registration.id) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if shell.isEnabled(registration.id) {
                // Stacked label-over-segments: a side-by-side label squeezes the segments until the text clips.
                // A menu, not segments: two options do not need a control as tall as a row, and the menu keeps the
                // label and the choice on one line at any window width.
                Picker(selection: Binding(
                    get: { shell.placement(of: registration.id) },
                    set: { shell.setPlacement($0, for: registration.id) }
                )) {
                    Text(Strings.showInMenuBar).tag(MenuBarPlacement.ownIcon)
                    Text(Strings.hubOnly).tag(MenuBarPlacement.hubOnly)
                } label: {
                    Text(Strings.menuBar)
                        .foregroundStyle(.secondary)
                }
                .pickerStyle(.menu)

                if let detail = registration.tool.settingsView() {
                    detail
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private final class SettingsWindow: NSWindow {
    var onBecomeKey: (() -> Void)?

    override func becomeKey() {
        super.becomeKey()
        onBecomeKey?()
    }

    // The app has no main menu, so nothing else maps ⌘W to closing the window.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
