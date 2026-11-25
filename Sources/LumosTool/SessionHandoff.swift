import Foundation

/// What a session needs to carry on in the Prism that an update opens, written just before the old process quits.
///
/// Only a fresh record counts: one left by a relaunch that never happened, or found after a crash, would bring back a
/// session nobody expects.
struct SessionHandoff: Equatable {
    static let key = "tools.lumos.handoff"
    static let maximumAge: TimeInterval = 60

    var writtenAt: Date
    var startedAt: Date
    /// Nil for a session until stopped.
    var endsAt: Date?
    var length: SessionLength
    /// The lid setting was on, from this app's flag, which the relaunch keeps open in between.
    var keepsLidOverride: Bool

    func save(to defaults: UserDefaults) {
        var record: [String: Any] = [
            "writtenAt": writtenAt,
            "startedAt": startedAt,
            "length": length.rawValue,
            "lidClosed": keepsLidOverride,
        ]
        record["endsAt"] = endsAt
        defaults.set(record, forKey: Self.key)
    }

    /// Reads the record and deletes it, so it is used at most once.
    static func take(from defaults: UserDefaults) -> SessionHandoff? {
        guard defaults.object(forKey: key) != nil else { return nil }
        defer { defaults.removeObject(forKey: key) }
        guard let record = defaults.dictionary(forKey: key),
              let writtenAt = record["writtenAt"] as? Date,
              let startedAt = record["startedAt"] as? Date,
              let length = (record["length"] as? Int).flatMap(SessionLength.init(rawValue:)) else { return nil }
        return SessionHandoff(
            writtenAt: writtenAt,
            startedAt: startedAt,
            endsAt: record["endsAt"] as? Date,
            length: length,
            keepsLidOverride: record["lidClosed"] as? Bool ?? false
        )
    }

    static func discard(in defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }

    /// Why the record cannot be used at `now`, or nil when it can.
    func rejection(at now: Date) -> String? {
        let age = now.timeIntervalSince(writtenAt)
        if abs(age) > Self.maximumAge {
            return "written \(Int(age.rounded())) s ago"
        }
        if let endsAt, endsAt <= now {
            return "the session ended \(Int(now.timeIntervalSince(endsAt).rounded())) s ago"
        }
        return nil
    }
}
