import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    enum Tab: String, CaseIterable {
        case general
        case pet
        case about
    }

    private static var shared: SettingsWindowController?

    /// One window for the whole app: the panel and the status item menu both open it, and a second copy would
    /// stack on top of the first.
    static func shared(for model: AppModel) -> SettingsWindowController {
        if let shared { return shared }
        let controller = SettingsWindowController(model: model)
        shared = controller
        return controller
    }

    private let model: AppModel
    private var window: NSWindow?

    private init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // An accessory app has to activate itself, or the window opens behind the frontmost app.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func makeWindow(selecting tab: Tab = .general) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for tab in Tab.allCases {
            let page = controller(for: tab)
            page.title = title(of: tab)
            let item = NSTabViewItem(viewController: page)
            item.label = title(of: tab)
            item.image = NSImage(systemSymbolName: symbol(of: tab), accessibilityDescription: title(of: tab))
            tabs.addTabViewItem(item)
        }
        tabs.selectedTabViewItemIndex = Tab.allCases.firstIndex(of: tab) ?? 0
        let window = SettingsWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        // Returning from System Settings makes the window key again, so this also catches changes made there.
        window.onBecomeKey = { [model] in
            model.loginItem.refresh()
            Task { await model.lid.refresh() }
        }
        window.center()
        return window
    }

    private func controller(for tab: Tab) -> NSViewController {
        switch tab {
        case .general:
            Self.host(GeneralSettingsView(model: model))
        case .pet:
            Self.host(PetSettingsView(model: model))
        case .about:
            Self.host(AboutSettingsView())
        }
    }

    // The tab view controller resizes the window to the selected page's preferred size.
    private static func host(_ view: some View) -> NSViewController {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        return controller
    }

    private func title(of tab: Tab) -> String {
        switch tab {
        case .general: Strings.generalTab
        case .pet: Strings.yourPet
        case .about: Strings.aboutTab
        }
    }

    private func symbol(of tab: Tab) -> String {
        switch tab {
        case .general: "gearshape"
        case .pet: "sun.max"
        case .about: "info.circle"
        }
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
