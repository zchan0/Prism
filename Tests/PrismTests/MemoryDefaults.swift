import Foundation

/// Settings that live only as long as the test. A `UserDefaults(suiteName:)` suite writes a plist to
/// ~/Library/Preferences on its first write, and removing the suite afterwards leaves an empty plist behind.
///
/// The typed accessors, such as `bool(forKey:)` and `set(_:forKey:)` with an `Int`, go through these four methods.
final class MemoryDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    override func object(forKey key: String) -> Any? {
        lock.withLock { values[key] }
    }

    override func set(_ value: Any?, forKey key: String) {
        lock.withLock { values[key] = value }
    }

    override func removeObject(forKey key: String) {
        lock.withLock { values[key] = nil }
    }

    override func dictionaryRepresentation() -> [String: Any] {
        lock.withLock { values }
    }
}
