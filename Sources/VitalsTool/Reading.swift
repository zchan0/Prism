import Foundation

/// One system reading: how much of something is left, and how full it is.
///
/// Disk, memory and battery are the same shape, so the tool, the menu bar icon and the panel are written once
/// against this instead of three times against three unrelated APIs.
public struct Reading: Equatable, Sendable, Identifiable {
    public enum Kind: String, CaseIterable, Sendable {
        case cpu
        case memory
        case disk
        case battery

        public var id: String { rawValue }

        /// The symbol before there is a reading. A battery's own symbol empties with its charge.
        public var symbolName: String {
            switch self {
            case .cpu: "cpu"
            case .memory: "memorychip"
            case .disk: "internaldrive"
            case .battery: "battery.100percent"
            }
        }
    }

    public let kind: Kind
    /// "119 GB" or "62%".
    public let value: String
    /// "of 494 GB", "of 16 GB", "charging".
    public let detail: String
    /// How full the thing is, 0...1. Used for the bar and for the menu bar glyph.
    public let fraction: Double
    /// True when this reading is close to running out, so the UI can warn.
    public let isTight: Bool
    /// A second line under the bar, such as the battery's health.
    public let note: String?

    public init(kind: Kind, value: String, detail: String, fraction: Double, isTight: Bool = false, note: String? = nil) {
        self.kind = kind
        self.value = value
        self.detail = detail
        self.fraction = min(1, max(0, fraction))
        self.isTight = isTight
        self.note = note
    }

    public var symbolName: String {
        kind == .battery ? Self.batterySymbol(percent: Int((fraction * 100).rounded())) : kind.symbolName
    }

    /// The battery glyph closest to the level, so the icon drains the way the system's own does.
    public static func batterySymbol(percent: Int) -> String {
        switch percent {
        case 88...: "battery.100percent"
        case 63...: "battery.75percent"
        case 38...: "battery.50percent"
        case 13...: "battery.25percent"
        default: "battery.0percent"
        }
    }

    public var summary: String { "\(value) \(detail)" }

    /// The value as the menu bar shows it. The CPU load is padded to three digits with figure spaces, which are as
    /// wide as a digit, so the icon keeps its width as the load moves between 5% and 100%.
    public var menuBarText: String {
        guard kind == .cpu else { return value }
        let digits = value.filter(\.isNumber).count
        return String(repeating: "\u{2007}", count: max(0, 3 - digits)) + value
    }

    public var id: String { kind.rawValue }
}

/// "119 GB", the way Finder says it. Rounded to whole units here, because the menu bar must not change width as the
/// number creeps down.
public enum ByteText {
    public static func compact(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    public static func short(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = false
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
