import AppKit
import Observation
import PrismKit
import SwiftUI

/// System readings in the menu bar: CPU, memory, disk and battery.
///
/// Each reading the person turns on gets its own icon in the menu bar, so each one can be ⌘-dragged or hidden on its
/// own. All of them are in the panel.
@MainActor
@Observable
public final class VitalsTool: Tool {
    public static let id = ToolID("vitals")

    private let settings: ToolSettings
    private let ticker = Ticker()
    /// The readings with an icon in the menu bar. Disk alone by default: it changes slowly, so its number does not
    /// flicker.
    public private(set) var menuBarKinds: Set<Reading.Kind>
    public var showsValueInMenuBar: Bool {
        didSet { settings.set(showsValueInMenuBar, for: "showsValue") }
    }

    public private(set) var cpu: CPUReading?
    public private(set) var disk: DiskReading?
    public private(set) var memory: MemoryReading?
    public private(set) var battery: BatteryReading?
    private var started = false
    @ObservationIgnored private var lastTicks: CPUTicks?
    @ObservationIgnored private var glyphs: [Reading.Kind: MenuBarGlyph.Cache] = [:]

    public init(settings: ToolSettings = ToolSettings(tool: VitalsTool.id)) {
        self.settings = settings
        menuBarKinds = Set(Reading.Kind.allCases.filter { settings.bool(Self.menuBarKey($0), default: $0 == .disk) })
        showsValueInMenuBar = settings.bool("showsValue", default: true)
        refresh()
    }

    public var title: String { "Vitals" }
    public var tagline: String { VitalsStrings.tagline }
    public var symbolName: String { menuBarReadings.first?.symbolName ?? Reading.Kind.disk.symbolName }
    public var tint: ToolTint { Palette.vitals }

    /// The first reading in the menu bar, the way the Prism window's list has room for: "78.95 GB free".
    public var summary: String {
        menuBarReadings.first?.shortSummary ?? VitalsStrings.unavailable
    }

    /// Every reading that has something to say, fastest-moving first.
    public var readings: [Reading] {
        [cpu?.reading, memory?.reading, disk?.reading, battery?.reading].compactMap { $0 }
    }

    public var menuBarReadings: [Reading] {
        readings.filter { menuBarKinds.contains($0.kind) }
    }

    /// Turning off the last one is refused: taking Vitals out of the menu bar is the shell's own switch.
    public func setInMenuBar(_ kind: Reading.Kind, _ isOn: Bool) {
        guard isOn || menuBarKinds != [kind] else { return }
        if isOn {
            menuBarKinds.insert(kind)
        } else {
            menuBarKinds.remove(kind)
        }
        settings.set(isOn, for: Self.menuBarKey(kind))
    }

    private static func menuBarKey(_ kind: Reading.Kind) -> String {
        "menuBar.\(kind.rawValue)"
    }

    public func start() {
        guard !started else { return }
        started = true
        refresh()
        // Every reading moves on one slow timer, so the panel does not have one number jumping while the rest sit still.
        ticker.start(every: 20) { [weak self] in self?.refresh() }
        // CPU load is the difference between two samples, so the first reading needs a second sample soon after.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, started else { return }
            refresh()
        }
    }

    public func stop() {
        started = false
        ticker.stop()
        lastTicks = nil
        cpu = nil
    }

    private func sampleCPU() {
        guard started, let ticks = CPUTicks.read() else { return }
        if let lastTicks, let next = CPUReading.between(lastTicks, ticks), next != cpu {
            cpu = next
        }
        lastTicks = ticks
    }

    public func refresh() {
        sampleCPU()
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
        case .cpu: cpu != nil
        case .disk: disk != nil
        case .memory: memory != nil
        case .battery: battery?.hasBattery ?? false
        }
    }

    public func statusIcons() -> [StatusIcon] {
        Reading.Kind.allCases.filter(menuBarKinds.contains).compactMap { kind in
            let reading = readings.first { $0.kind == kind }
            // CPU load needs a second sample, so until then its icon shows without a number rather than appear late.
            guard reading != nil || kind == .cpu else { return nil }
            let glyph = glyphs[kind] ?? MenuBarGlyph.Cache()
            glyphs[kind] = glyph
            return StatusIcon(id: kind.rawValue, image: glyph.image(
                symbol: reading?.symbolName ?? kind.symbolName,
                text: showsValueInMenuBar ? reading?.menuBarText : nil,
                accessibilityDescription: reading?.summary ?? kind.name
            ))
        }
    }

    public func controlsView() -> AnyView {
        AnyView(VitalsPanelView(tool: self))
    }

    public func menuBarSettings() -> MenuBarSettings? {
        MenuBarSettings(rows: AnyView(VitalsMenuBarSettingsView(tool: self)), note: VitalsStrings.menuBarNote)
    }
}

internal enum VitalsStrings {
    static let tagline = String(localized: "CPU, memory, disk and battery at a glance.")
    static let unavailable = String(localized: "No reading")
    static func freeOfTotal(_ total: String) -> String { String(localized: "free of \(total)") }
    static func free(_ amount: String) -> String { String(localized: "\(amount) free") }
    static func used(_ amount: String) -> String { String(localized: "\(amount) used") }
    static func cpuLoad(_ load: String) -> String { String(localized: "CPU \(load)") }
    static func batteryLevel(_ level: String) -> String { String(localized: "Battery \(level)") }
    static func ofTotal(_ total: String) -> String { String(localized: "of \(total)") }
    static func percent(_ level: Int) -> String { String(localized: "\(level)%") }
    static let charging = String(localized: "charging")
    static let pluggedIn = String(localized: "plugged in")
    static let onBattery = String(localized: "on battery")
    static let cpuName = String(localized: "CPU")
    static func cpuSplit(user: Int, system: Int) -> String { String(localized: "user \(user)% · system \(system)%") }
    static func maximumCapacity(_ percent: Int) -> String { String(localized: "Maximum capacity \(percent)%") }
    static func cycles(_ count: Int) -> String { String(localized: "\(count) cycles") }
    static let diskName = String(localized: "Disk")
    static let memoryName = String(localized: "Memory")
    static let batteryName = String(localized: "Battery")
    static let showValue = String(localized: "Show the number next to the icon")
    static let menuBarNote = String(localized: "Readings refresh every 20 seconds. Free disk space includes what macOS can reclaim, which is the number Finder shows.")
}
