import Foundation
import PrismKit
import Testing

/// Two tools sharing one defaults database must not be able to read or clobber each other's keys.
@MainActor
struct ToolSettingsTests {
    @Test func twoToolsWithTheSameKeyNameDoNotCollide() {
        let defaults = MemoryDefaults()
        let lumos = ToolSettings(tool: ToolID("lumos"), defaults: defaults)
        let disk = ToolSettings(tool: ToolID("disk"), defaults: defaults)

        lumos.setPlainInt(30, for: "threshold")
        disk.setPlainInt(90, for: "threshold")

        #expect(lumos.plainInt("threshold", default: 0) == 30)
        #expect(disk.plainInt("threshold", default: 0) == 90)
    }

    @Test func valuesSurviveANewInstance() {
        let defaults = MemoryDefaults()
        ToolSettings(tool: ToolID("disk"), defaults: defaults).set("Volumes/Backup", for: "volumePath")
        #expect(ToolSettings(tool: ToolID("disk"), defaults: defaults).string("volumePath", default: "/") == "Volumes/Backup")
    }

    @Test func aToolOnlySeesItsOwnKeys() {
        let defaults = MemoryDefaults()
        let lumos = ToolSettings(tool: ToolID("lumos"), defaults: defaults)
        let disk = ToolSettings(tool: ToolID("disk"), defaults: defaults)
        lumos.set(true, for: "showsTimeInMenuBar")
        disk.set(true, for: "showsFreeSpace")

        #expect(lumos.allKeys == ["showsTimeInMenuBar"])
        #expect(disk.allKeys == ["showsFreeSpace"])
    }
}
