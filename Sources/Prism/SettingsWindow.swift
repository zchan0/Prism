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
        hosting.sizingOptions = .preferredContentSize
        let window = SettingsWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.title = Strings.appName
        window.onBecomeKey = { [loginItem] in loginItem.refresh() }
        window.center()
        return window
    }
}

/// One scrolling form: shell settings on top, then a section per tool. A tool's section comes from its own
/// `settingsView()`, so the shell never lists what a tool can configure.
struct SettingsRootView: View {
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
                Picker(selection: Binding(get: { shell.hubPlacement }, set: { shell.hubPlacement = $0 })) {
                    Text(Strings.showInMenuBar).tag(MenuBarPlacement.ownIcon)
                    Text(Strings.hubOnly).tag(MenuBarPlacement.hubOnly)
                } label: {
                    Text(Strings.hubMenuBar)
                    Text(Strings.hubMenuBarNote)
                }
            }

            Section {
                ForEach(registrations, id: \.id) { registration in
                    toolRow(registration)
                }
            } header: {
                Text(Strings.toolsSection)
            } footer: {
                Text(Strings.toolsFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(Strings.shortcuts) {
                LabeledContent(Strings.togglePanelShortcut) {
                    Text(verbatim: GlobalHotKey.keyName)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func toolRow(_ registration: ToolRegistration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { shell.isEnabled(registration.id) },
                set: { shell.setEnabled($0, for: registration.id) }
            )) {
                Text(registration.tool.title)
            }
            Picker("", selection: Binding(
                get: { shell.placement(of: registration.id) },
                set: { shell.setPlacement($0, for: registration.id) }
            )) {
                Text(Strings.showInMenuBar).tag(MenuBarPlacement.ownIcon)
                Text(Strings.hubOnly).tag(MenuBarPlacement.hubOnly)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!shell.isEnabled(registration.id))
            if shell.isEnabled(registration.id), let detail = registration.tool.settingsView() {
                detail
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 2)
    }

    private var loginNote: String? {
        if let error = loginItem.error { return error }
        return loginItem.status == .requiresApproval ? Strings.loginItemNeedsApproval : nil
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
