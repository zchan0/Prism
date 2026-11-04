import Foundation
import Observation

/// Per-tool settings, namespaced so two tools can never collide on a key.
///
/// Plain `UserDefaults` keys were fine while the app was one feature. With several tools in one bundle, an unprefixed
/// key like "lastLength" is a bug waiting for the second tool that also wants to remember a length.
@MainActor
public final class ToolSettings {
    private let defaults: UserDefaults
    private let namespace: String

    public init(tool: ToolID, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        namespace = "tools.\(tool.rawValue)."
    }

    public func bool(_ key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: namespace + key) as? Bool ?? fallback
    }

    public func set(_ value: Bool, for key: String) {
        defaults.set(value, forKey: namespace + key)
    }

    public func plainInt(_ key: String, default fallback: Int) -> Int {
        defaults.object(forKey: namespace + key) as? Int ?? fallback
    }

    public func setPlainInt(_ value: Int, for key: String) {
        defaults.set(value, forKey: namespace + key)
    }

    public func int<Value: RawRepresentable>(_ key: String, default fallback: Value) -> Value where Value.RawValue == Int {
        defaults.object(forKey: namespace + key).flatMap { $0 as? Int }.flatMap(Value.init(rawValue:)) ?? fallback
    }

    public func set<Value: RawRepresentable>(_ value: Value, for key: String) where Value.RawValue == Int {
        defaults.set(value.rawValue, forKey: namespace + key)
    }

    public func string(_ key: String, default fallback: String) -> String {
        defaults.string(forKey: namespace + key) ?? fallback
    }

    public func set(_ value: String, for key: String) {
        defaults.set(value, forKey: namespace + key)
    }

    public func double(_ key: String) -> Double? {
        defaults.object(forKey: namespace + key) as? Double
    }

    public func set(_ value: Double?, for key: String) {
        guard let value else {
            defaults.removeObject(forKey: namespace + key)
            return
        }
        defaults.set(value, forKey: namespace + key)
    }

    public func remove(_ key: String) {
        defaults.removeObject(forKey: namespace + key)
    }

    public var allKeys: [String] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(namespace) }
            .map { String($0.dropFirst(namespace.count)) }
            .sorted()
    }
}

/// Which tools are on, and how each one shows up. Shell-level settings, not any tool's own.
@MainActor
@Observable
public final class ShellSettings {
    private enum Key {
        static let enabled = "shell.enabledTools"
        static let placements = "shell.placements"
        static let hubPlacement = "shell.hubPlacement"
    }

    /// Turning a tool off stops it and hides it; its settings are kept for when it comes back.
    public private(set) var enabled: Set<ToolID>
    /// Every tool's placement, whether or not it is enabled, so turning it back on restores the choice.
    public private(set) var placements: [ToolID: MenuBarPlacement]
    public var hubPlacement: MenuBarPlacement {
        didSet { defaults.set(hubPlacement.rawValue, forKey: Key.hubPlacement) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(registrations: [ToolRegistration], defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedEnabled = defaults.stringArray(forKey: Key.enabled).map { $0.map(ToolID.init(rawValue:)) }
        // A tool that has never been seen before starts on, which is what makes adding a tool to a release feel like
        // the app grew rather than like something broke.
        enabled = storedEnabled.map(Set.init) ?? Set(registrations.map(\.id))
        var storedPlacements = (defaults.dictionary(forKey: Key.placements) as? [String: String]) ?? [:]
        for registration in registrations where storedPlacements[registration.id.rawValue] == nil {
            storedPlacements[registration.id.rawValue] = registration.defaultPlacement.rawValue
        }
        placements = storedPlacements.reduce(into: [:]) { result, pair in
            guard let placement = MenuBarPlacement(rawValue: pair.value) else { return }
            result[ToolID(rawValue: pair.key)] = placement
        }
        hubPlacement = defaults.string(forKey: Key.hubPlacement)
            .flatMap(MenuBarPlacement.init(rawValue:)) ?? .ownIcon
    }

    public func isEnabled(_ id: ToolID) -> Bool { enabled.contains(id) }

    public func placement(of id: ToolID) -> MenuBarPlacement {
        placements[id] ?? .hubOnly
    }

    public func setEnabled(_ isOn: Bool, for id: ToolID) {
        if isOn {
            enabled.insert(id)
        } else {
            enabled.remove(id)
        }
        defaults.set(enabled.map(\.rawValue).sorted(), forKey: Key.enabled)
    }

    public func setPlacement(_ placement: MenuBarPlacement, for id: ToolID) {
        placements[id] = placement
        var stored = (defaults.dictionary(forKey: Key.placements) as? [String: String]) ?? [:]
        stored[id.rawValue] = placement.rawValue
        defaults.set(stored, forKey: Key.placements)
    }
}
