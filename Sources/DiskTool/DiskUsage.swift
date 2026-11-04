import Foundation

/// What the volume reports, in the three numbers macOS gives.
///
/// `available` is "free space right now". `forImportantUsage` includes purgeable space the system would reclaim for
/// a user-initiated save, so Finder's "Available" is the larger number. Showing the smaller one without saying so
/// makes people think the app is broken when Finder disagrees.
public struct DiskUsage: Equatable, Sendable {
    public var total: Int64
    public var available: Int64
    public var forImportantUsage: Int64
    public var volumeName: String
    public var isInternal: Bool

    public init(total: Int64, available: Int64, forImportantUsage: Int64, volumeName: String, isInternal: Bool) {
        self.total = total
        self.available = available
        self.forImportantUsage = forImportantUsage
        self.volumeName = volumeName
        self.isInternal = isInternal
    }

    /// The number Finder shows. Capacity keys report 0 when they are unavailable, so fall back to the plain one.
    public var shownAvailable: Int64 {
        forImportantUsage > 0 ? forImportantUsage : available
    }

    public var used: Int64 { max(0, total - shownAvailable) }
    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }
}

public enum DiskUsageReader {
    public static let keys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeIsInternalKey,
    ]

    public static func read(volumeAt path: String = "/") -> DiskUsage? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        return DiskUsage(
            total: Int64(values.volumeTotalCapacity ?? 0),
            available: (values.volumeAvailableCapacity).map(Int64.init) ?? 0,
            forImportantUsage: values.volumeAvailableCapacityForImportantUsage ?? 0,
            volumeName: values.volumeName ?? "Macintosh HD",
            isInternal: values.volumeIsInternal ?? true
        )
    }
}

/// "119 GB", the way Finder says it. One decimal above 10, none below, so the menu bar does not wobble in width.
public enum ByteText {
    public static func compact(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useTB]
        formatter.countStyle = .decimal
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}
