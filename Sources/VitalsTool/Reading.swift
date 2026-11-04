import Foundation

/// One system reading: how much of something is left, and how full it is.
///
/// Disk, memory and battery are the same shape, so the tool, the menu bar icon and the panel are written once
/// against this instead of three times against three unrelated APIs.
public struct Reading: Equatable, Sendable, Identifiable {
    public enum Kind: String, CaseIterable, Sendable {
        case disk
        case memory
        case battery

        public var id: String { rawValue }
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

    public init(kind: Kind, value: String, detail: String, fraction: Double, isTight: Bool = false) {
        self.kind = kind
        self.value = value
        self.detail = detail
        self.fraction = min(1, max(0, fraction))
        self.isTight = isTight
    }

    public var symbolName: String {
        switch kind {
        case .disk: "internaldrive.fill"
        case .memory: "memorychip.fill"
        case .battery: "battery.100percent"
        }
    }

    public var summary: String { "\(value) \(detail)" }

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
