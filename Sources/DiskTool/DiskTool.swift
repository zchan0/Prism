import AppKit
import Observation
import PrismKit
import SwiftUI

/// Shows how much room is left on a volume.
///
/// It refreshes on a slow timer on purpose: a capacity read walks the filesystem's volume metadata, and doing that
/// once a second would cost more than the tool is worth. The panel opening forces an extra read, which is when
/// anybody actually looks at the number.
@MainActor
@Observable
public final class DiskTool: Tool {
    public static let id = ToolID("disk")

    private let settings: ToolSettings
    private let ticker = Ticker()
    private(set) var usage: DiskUsage?
    private var started = false
    private var lastImage: NSImage?

    /// How often the number refreshes on its own. Also the timer's only reason to exist.
    static let refreshInterval: TimeInterval = 60

    public init(settings: ToolSettings = ToolSettings(tool: DiskTool.id)) {
        self.settings = settings
        usage = DiskUsageReader.read(volumeAt: volumePath)
    }

    public var volumePath: String {
        get { settings.string("volumePath", default: "/") }
        set { settings.set(newValue, for: "volumePath") }
    }

    public var showsFreeSpaceInMenuBar: Bool {
        get { settings.bool("showsFreeSpace", default: true) }
        set { settings.set(newValue, for: "showsFreeSpace") }
    }

    public var title: String { usage?.volumeName ?? "Disk" }
    public var symbolName: String { "internaldrive.fill" }

    public var summary: String {
        guard let usage else { return DiskStrings.unavailable }
        return DiskStrings.freeOfTotal(ByteText.compact(usage.shownAvailable), ByteText.compact(usage.total))
    }

    public func start() {
        guard !started else { return }
        started = true
        refresh()
        ticker.start(every: Self.refreshInterval) { [weak self] in self?.refresh() }
    }

    public func stop() {
        started = false
        ticker.stop()
    }

    public func refresh() {
        let next = DiskUsageReader.read(volumeAt: volumePath)
        guard next != usage else { return }
        usage = next
    }

    public func statusItemImage() -> NSImage? {
        guard let usage else { return nil }
        let image = DiskMenuIcon.image(usage: usage, showsText: showsFreeSpaceInMenuBar)
        guard image !== lastImage else { return lastImage }
        lastImage = image
        return image
    }

    public func hubView() -> AnyView? {
        AnyView(DiskToolView(tool: self))
    }

    public func settingsView() -> AnyView? {
        AnyView(DiskSettingsView(tool: self))
    }
}

internal enum DiskStrings {
    static let unavailable = String(localized: "No volume")
    static func freeOfTotal(_ free: String, _ total: String) -> String {
        String(localized: "\(free) free of \(total)")
    }
    static let used = String(localized: "Used")
    static let free = String(localized: "Available")
    static let capacity = String(localized: "Capacity")
    static let volume = String(localized: "Volume")
    static let showFreeSpace = String(localized: "Show free space next to the icon")
    static let refreshNote = String(localized: "Refreshes every minute, and whenever the panel opens.")
    static let forImportantUsage = String(localized: "Includes space macOS can reclaim when it needs it, which is the number Finder shows.")
    static let noVolume = String(localized: "This volume is not available.")
}
