import Foundation

/// Free space on a volume.
///
/// `available` is free right now. `forImportantUsage` includes purgeable space the system reclaims for a
/// user-initiated save, which is the number Finder shows. Using the smaller one makes the app disagree with Finder
/// by several gigabytes.
public struct DiskReading: Equatable, Sendable {
    public var total: Int64
    public var available: Int64
    public var forImportantUsage: Int64
    public var volumeName: String

    public init(total: Int64, available: Int64, forImportantUsage: Int64, volumeName: String) {
        self.total = total
        self.available = available
        self.forImportantUsage = forImportantUsage
        self.volumeName = volumeName
    }

    public var shownAvailable: Int64 { forImportantUsage > 0 ? forImportantUsage : available }
    public var used: Int64 { max(0, total - shownAvailable) }
    public var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    public var reading: Reading {
        Reading(
            kind: .disk,
            value: ByteText.compact(shownAvailable),
            detail: VitalsStrings.freeOfTotal(ByteText.compact(total)),
            fraction: usedFraction,
            isTight: usedFraction > 0.92
        )
    }

    public static func read(volumeAt path: String = "/") -> DiskReading? {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        return DiskReading(
            total: Int64(values.volumeTotalCapacity ?? 0),
            available: values.volumeAvailableCapacity.map(Int64.init) ?? 0,
            forImportantUsage: values.volumeAvailableCapacityForImportantUsage ?? 0,
            volumeName: values.volumeName ?? "Macintosh HD"
        )
    }
}
