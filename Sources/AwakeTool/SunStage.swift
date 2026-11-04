import Foundation

/// The pet grows with the hours it has kept the Mac awake; the thresholds are pure so tests can pin them.
public enum SunStage: Int, CaseIterable, Sendable, Comparable {
    case spark
    case ember
    case flare
    case sol
    case nova

    public static func < (lhs: SunStage, rhs: SunStage) -> Bool { lhs.rawValue < rhs.rawValue }

    public var requiredHours: Double {
        switch self {
        case .spark: 0
        case .ember: 1
        case .flare: 3
        case .sol: 6
        case .nova: 10
        }
    }

    public var scale: Double {
        switch self {
        case .spark: 0.72
        case .ember: 0.84
        case .flare: 0.94
        case .sol: 1.03
        case .nova: 1.12
        }
    }

    /// The next threshold as a fraction of the way there, for the growth ring.
    public static func progress(for hours: Double) -> Double {
        guard let next = stage(for: hours).next else { return 1 }
        let current = stage(for: hours).requiredHours
        return min(1, max(0, (hours - current) / (next.requiredHours - current)))
    }

    public static func stage(for hours: Double) -> SunStage {
        Self.allCases.last { hours >= $0.requiredHours } ?? .spark
    }

    public var next: SunStage? {
        Self.allCases.first { $0.rawValue == rawValue + 1 }
    }
}
