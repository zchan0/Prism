import Foundation

/// Cross-module notifications the shell and tools use instead of importing each other.
public extension Notification.Name {
    /// A tool asks the shell to open Settings. Sent by the awake tool's double-click on the pet.
    static let prismOpenSettings = Notification.Name("prism.openSettings")
    /// The shell asks every tool to redraw, used when the panel opens.
    static let prismRefreshTools = Notification.Name("prism.refreshTools")
}

public enum PrismNotifications {
    public static let openSettings = Notification.Name.prismOpenSettings
    public static let refreshTools = Notification.Name.prismRefreshTools
}
