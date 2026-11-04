import Foundation
import PrismKit
import Testing

/// The rename from LumosMaxima to Prism must look like an upgrade, not a reinstall: the pet's age, the chosen length
/// and the lid switch all live in UserDefaults under the old bare keys.
struct SettingsMigrationTests {
    private func freshDefaults() -> (UserDefaults, String) {
        let name = "migration." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test func copiesTheOldKeysIntoTheirToolNamespace() {
        let (defaults, _) = freshDefaults()
        defaults.set(3600, forKey: "lastLength")
        defaults.set(12, forKey: "petCount")
        defaults.set(1204.0, forKey: "petOriginX")

        SettingsMigration.runIfNeeded(defaults: defaults)

        #expect(defaults.object(forKey: "tools.awake.lastLength") as? Int == 3600)
        #expect(defaults.object(forKey: "tools.awake.petCount") as? Int == 12)
        #expect(defaults.object(forKey: "tools.awake.petOriginX") as? Double == 1204.0)
    }

    @Test func neverOverwritesAValueThePersonSetInThisVersion() {
        let (defaults, _) = freshDefaults()
        defaults.set(3600, forKey: "lastLength")
        defaults.set(1800, forKey: "tools.awake.lastLength")

        SettingsMigration.runIfNeeded(defaults: defaults)

        #expect(defaults.object(forKey: "tools.awake.lastLength") as? Int == 1800)
    }

    @Test func runsOnlyOnce() {
        let (defaults, _) = freshDefaults()
        defaults.set(12, forKey: "petCount")
        SettingsMigration.runIfNeeded(defaults: defaults)
        #expect(defaults.object(forKey: "tools.awake.petCount") as? Int == 12)

        // A value written after the migration must survive, even though the old key still exists.
        defaults.set(99, forKey: "tools.awake.petCount")
        defaults.set(1, forKey: "petCount")
        SettingsMigration.runIfNeeded(defaults: defaults)
        #expect(defaults.object(forKey: "tools.awake.petCount") as? Int == 99)
    }

    @Test func aFreshInstallGetsNothingCopied() {
        let (defaults, _) = freshDefaults()
        #expect(SettingsMigration.preview(defaults: defaults).isEmpty)
    }
}

/// Two tools sharing one defaults database must not be able to read or clobber each other's keys.
@MainActor
struct ToolSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "toolsettings." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func twoToolsWithTheSameKeyNameDoNotCollide() {
        let defaults = freshDefaults()
        let awake = ToolSettings(tool: ToolID("awake"), defaults: defaults)
        let disk = ToolSettings(tool: ToolID("disk"), defaults: defaults)

        awake.setPlainInt(30, for: "threshold")
        disk.setPlainInt(90, for: "threshold")

        #expect(awake.plainInt("threshold", default: 0) == 30)
        #expect(disk.plainInt("threshold", default: 0) == 90)
    }

    @Test func valuesSurviveANewInstance() {
        let defaults = freshDefaults()
        ToolSettings(tool: ToolID("disk"), defaults: defaults).set("Volumes/Backup", for: "volumePath")
        #expect(ToolSettings(tool: ToolID("disk"), defaults: defaults).string("volumePath", default: "/") == "Volumes/Backup")
    }

    @Test func aToolOnlySeesItsOwnKeys() {
        let defaults = freshDefaults()
        let awake = ToolSettings(tool: ToolID("awake"), defaults: defaults)
        let disk = ToolSettings(tool: ToolID("disk"), defaults: defaults)
        awake.set(true, for: "showsPet")
        disk.set(true, for: "showsFreeSpace")

        #expect(awake.allKeys == ["showsPet"])
        #expect(disk.allKeys == ["showsFreeSpace"])
    }
}
