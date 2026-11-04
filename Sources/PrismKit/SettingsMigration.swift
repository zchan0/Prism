import Foundation

/// Moves settings written by the single-tool app into the per-tool namespaces.
///
/// The first Prism release still carried the LumosMaxima bundle id, so the old keys are sitting in `UserDefaults`
/// under names like `lastLength`. A tool now reads `tools.awake.lastLength`, and without this it would look like a
/// fresh install: the pet would restart, the chosen length would reset, the lid switch would forget itself.
///
/// Runs once. A version marker stops it from resurrecting a setting the person later changed on purpose.
public enum SettingsMigration {
    private static let marker = "prism.migratedFromSingleToolApp"

    /// Old key → namespaced key. Only keys the old app actually wrote.
    static let moves: [(from: String, to: String)] = [
        ("showsPet", "tools.awake.showsPet"),
        ("showsTimeInMenuBar", "tools.awake.showsTimeInMenuBar"),
        ("keepsDisplayAwake", "tools.awake.keepsDisplayAwake"),
        ("keepsAwakeWithLidClosed", "tools.awake.keepsAwakeWithLidClosed"),
        ("lastLength", "tools.awake.lastLength"),
        ("lengthDefaultMigrated", "tools.awake.lengthDefaultMigrated"),
        ("lowBatteryThreshold", "tools.awake.lowBatteryThreshold"),
        ("notifiesWhenTimerEnds", "tools.awake.notifiesWhenTimerEnds"),
        ("notifiesWhenBatteryLow", "tools.awake.notifiesWhenBatteryLow"),
        ("petOriginX", "tools.awake.petOriginX"),
        ("petOriginY", "tools.awake.petOriginY"),
        ("petCount", "tools.awake.petCount"),
        ("awakeLog.day", "tools.awake.awakeLog.day"),
        ("awakeLog.seconds", "tools.awake.awakeLog.seconds"),
        ("lidSleepDisabledByLumosMaxima", "tools.awake.lidSleepDisabledByLumosMaxima"),
    ]

    public static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: marker) else { return }
        for move in moves {
            // A value already present in the new place wins; the person may have set it in this version.
            guard defaults.object(forKey: move.to) == nil,
                  let value = defaults.object(forKey: move.from) else { continue }
            defaults.set(value, forKey: move.to)
        }
        defaults.set(true, forKey: marker)
    }

    /// Exposed for tests: what the migration would copy, without touching anything.
    public static func preview(defaults: UserDefaults) -> [String: Any] {
        var result: [String: Any] = [:]
        for move in moves {
            guard defaults.object(forKey: move.to) == nil,
                  let value = defaults.object(forKey: move.from) else { continue }
            result[move.to] = value
        }
        return result
    }
}
