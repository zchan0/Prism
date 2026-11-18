#if DEBUG
public enum PortkeyDebug {
    @MainActor
    public static func switchTo(bundleID: String) {
        AppSwitcher.switchTo(AppSwitcher.Target(bundleID: bundleID, savedURL: nil))
    }

    @MainActor
    public static func openWindow(_ tool: PortkeyTool) {
        tool.openWindow()
    }
}
#endif
