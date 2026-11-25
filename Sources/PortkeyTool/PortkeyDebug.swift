#if DEBUG
import AppKit
import Carbon.HIToolbox
import PrismKit

public enum PortkeyDebug {
    @MainActor
    public static func switchTo(bundleID: String) {
        AppSwitcher.switchTo(AppSwitcher.Target(bundleID: bundleID, savedURL: nil))
    }

    /// For screenshots: puts sample apps in place of the person's apps, in memory only. Neither the person's shortcuts
    /// nor the samples' are set up, since another Prism may hold the same ones.
    @MainActor
    public static func showSamples(_ tool: PortkeyTool) {
        tool.showSamplesForDebug(samples)
    }

    /// Apps that every Mac has, the last one without a shortcut.
    static let samples: [PortkeyApp] = [
        sample("com.apple.Safari", "/Applications/Safari.app", "Safari", key(kVK_ANSI_S, optionKey | shiftKey, "S")),
        sample("com.apple.mail", "/System/Applications/Mail.app", "Mail", key(kVK_ANSI_M, optionKey | shiftKey, "M")),
        sample("com.apple.Notes", "/System/Applications/Notes.app", "Notes", key(kVK_ANSI_N, controlKey | cmdKey, "N")),
        sample("com.apple.Terminal", "/System/Applications/Utilities/Terminal.app", "Terminal", nil),
    ]

    private static func sample(
        _ bundleID: String,
        _ path: String,
        _ name: String,
        _ shortcut: Shortcut?
    ) -> PortkeyApp {
        // Safari in Applications is a link to the real app, and the icon of a link has an arrow on it.
        let path = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        return PortkeyApp(id: UUID(), bundleID: bundleID, path: path, name: name, shortcut: shortcut)
    }

    private static func key(_ keyCode: Int, _ modifiers: Int, _ keyName: String) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), keyName: keyName)
    }
}
#endif
