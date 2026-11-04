import AppKit
import Observation
import PrismKit
import SwiftUI

/// System readings in the menu bar: disk, memory and battery.
///
/// The tool shows one reading at a time in the menu bar — the one the person picked — because three numbers next to
/// three glyphs is more menu bar than this earns. All of them are in the panel.
@MainActor
@Observable
public final class VitalsTool: Tool {
    public static let id = ToolID("vitals")

    private let settings: ToolSettings
    private let ticker = Ticker()
    /// Which reading the menu bar shows. Disk by default: it changes slowly, so the number does not flicker.
    public var shown: Reading.Kind {
        get { Reading.Kind(rawValue: settings.string("shown", default: Reading.Kind.disk.rawValue)) ?? .disk }
        set { settings.set(newValue.rawValue, for: "shown") }
    }
    public var showsValueInMenuBar: Bool {
        get { settings.bool("showsValue", default: true) }
        set { settings.set(newValue, for: "showsValue") }
    }

    public private(set) var disk: DiskReading?
    public private(set) var memory: MemoryReading?
    public private(set) var battery: BatteryReading?
    private var started = false
    private var lastImage: NSImage?

    public init(settings: ToolSettings = ToolSettings(tool: VitalsTool.id)) {
        self.settings = settings
        refresh()
    }

    public var title: String { "Vitals" }
    public var symbolName: String { shownReading?.symbolName ?? "internaldrive.fill" }

    public var summary: String {
        guard let reading = shownReading else { return VitalsStrings.unavailable }
        return reading.summary
    }

    /// Every reading that has something to say, in a stable order.
    public var readings: [Reading] {
        [disk?.reading, memory?.reading, battery?.reading].compactMap { $0 }
    }

    public var shownReading: Reading? {
        readings.first { $0.kind == shown } ?? readings.first
    }

    public func start() {
        guard !started else { return }
        started = true
        refresh()
        // Memory moves constantly and disk barely moves; one slow timer keeps both honest without a per-second read.
        ticker.start(every: 20) { [weak self] in self?.refresh() }
    }

    public func stop() {
        started = false
        ticker.stop()
    }

    public func refresh() {
        let nextDisk = DiskReading.read(volumeAt: settings.string("volumePath", default: "/"))
        let nextMemory = MemoryReading.read()
        let nextBattery = BatteryReading.read()
        guard nextDisk != disk || nextMemory != memory || nextBattery != battery else { return }
        disk = nextDisk
        memory = nextMemory
        battery = nextBattery
    }

    public func isAvailable(_ kind: Reading.Kind) -> Bool {
        switch kind {
        case .disk: disk != nil
        case .memory: memory != nil
        case .battery: battery?.hasBattery ?? false
        }
    }

    public func statusItemImage() -> NSImage? {
        guard let reading = shownReading else { return nil }
        let image = VitalsIcon.image(reading: reading, showsValue: showsValueInMenuBar)
        guard image !== lastImage else { return lastImage }
        lastImage = image
        return image
    }

    public func hubView() -> AnyView? {
        AnyView(VitalsPanelView(tool: self))
    }

    public func settingsView() -> AnyView? {
        AnyView(VitalsSettingsView(tool: self))
    }
}

internal enum VitalsStrings {
    static let unavailable = String(localized: "No reading")
    static func freeOfTotal(_ total: String) -> String { String(localized: "free of \(total)") }
    static func ofTotal(_ total: String) -> String { String(localized: "of \(total)") }
    static func percent(_ level: Int) -> String { String(localized: "\(level)%") }
    static let charging = String(localized: "charging")
    static let pluggedIn = String(localized: "plugged in")
    static let onBattery = String(localized: "on battery")
    static let diskName = String(localized: "Disk")
    static let memoryName = String(localized: "Memory")
    static let batteryName = String(localized: "Battery")
    static let shownInMenuBar = String(localized: "Shows in the menu bar")
    static let showValue = String(localized: "Show the number next to the icon")
    static let refreshNote = String(localized: "Disk and memory refresh every 20 seconds, and whenever the panel opens.")
    static let includesReclaimable = String(localized: "Available includes space macOS can reclaim, which is the number Finder shows.")
}
