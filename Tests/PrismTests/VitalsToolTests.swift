import AppKit
import Foundation
import Observation
import PrismKit
import Testing
@testable import VitalsTool

struct DiskReadingTests {
    private func disk(total: Int64, available: Int64, important: Int64) -> DiskReading {
        DiskReading(total: total, available: available, forImportantUsage: important, volumeName: "Macintosh HD")
    }

    @Test func showsTheNumberFinderShows() {
        // Finder's "Available" counts purgeable space, so it is the larger of the two numbers macOS reports.
        let reading = disk(total: 494_384_795_648, available: 115_850_162_176, important: 119_158_744_749)
        #expect(reading.shownAvailable == 119_158_744_749)
    }

    @Test func fallsBackWhenTheCapacityIsUnavailable() {
        // macOS reports 0 for the important-usage key on some volumes; 0 would read as a full disk.
        #expect(disk(total: 1000, available: 400, important: 0).shownAvailable == 400)
    }

    @Test func usedIsTheRemainderOfShownAvailable() {
        let reading = disk(total: 1000, available: 400, important: 300)
        #expect(reading.used == 700)
        #expect(reading.usedFraction == 0.7)
    }

    @Test func nonsenseCapacitiesCannotProduceANegativeBar() {
        let reading = disk(total: 0, available: 99, important: 99)
        #expect(reading.used == 0)
        #expect(reading.usedFraction == 0)
    }

    @Test func readsTheRealBootVolume() throws {
        let real = try #require(DiskReading.read(volumeAt: "/"))
        #expect(real.total > 0)
        #expect(real.shownAvailable > 0)
        #expect(real.shownAvailable <= real.total)
    }
}

struct MemoryReadingTests {
    @Test func fractionStaysWithinTheBar() {
        #expect(MemoryReading(total: 100, used: 150).fraction == 1)
        #expect(MemoryReading(total: 100, used: -5).fraction == 0)
        #expect(MemoryReading(total: 0, used: 10).fraction == 0)
    }

    @Test func readsThisMachine() throws {
        let real = try #require(MemoryReading.read())
        #expect(real.total == Int64(ProcessInfo.processInfo.physicalMemory))
        // macOS always has something wired, so a zero reading means the syscall was misread.
        #expect(real.used > 0)
        #expect(real.used <= real.total)
    }
}

struct BatteryReadingTests {
    @Test func aDesktopHasNoBatteryReading() {
        let desktop = BatteryReading(level: 0, isCharging: false, isOnAC: true, hasBattery: false)
        #expect(desktop.reading == nil)
    }

    @Test func aLowUnpluggedBatteryIsTight() {
        let low = BatteryReading(level: 12, isCharging: false, isOnAC: false, hasBattery: true)
        #expect(low.reading?.isTight == true)
        #expect(low.reading?.fraction == 0.12)
    }

    @Test func chargingIsNeverTight() {
        let charging = BatteryReading(level: 8, isCharging: true, isOnAC: true, hasBattery: true)
        #expect(charging.reading?.isTight == false)
    }
}

struct CPUReadingTests {
    @Test func loadIsTheBusyShareOfTheTicksBetweenTwoSamples() {
        let old = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
        let new = CPUTicks(user: 190, system: 100, idle: 900, nice: 10)
        let reading = CPUReading.between(old, new)
        #expect(reading?.user == 0.4)
        #expect(reading?.system == 0.2)
        #expect(reading?.reading.value == "60%")
        #expect(reading?.reading.detail == "user 40% · system 20%")
    }

    @Test func wrappedCountersStillGiveTheDifference() {
        let old = CPUTicks(user: UInt32.max - 9, system: 0, idle: 0, nice: 0)
        let new = CPUTicks(user: 10, system: 0, idle: 20, nice: 0)
        #expect(CPUReading.between(old, new)?.user == 0.5)
    }

    @Test func noTimeBetweenSamplesGivesNoReading() {
        let ticks = CPUTicks(user: 1, system: 2, idle: 3, nice: 4)
        #expect(CPUReading.between(ticks, ticks) == nil)
    }

    @Test func aRealSampleCanBeTaken() {
        #expect(CPUTicks.read() != nil)
    }

    @Test func theMenuBarTextIsPaddedToThreeDigits() {
        #expect(CPUReading(user: 0.05, system: 0).reading.menuBarText == "\u{2007}\u{2007}5%")
        #expect(CPUReading(user: 1, system: 0).reading.menuBarText == "100%")
        #expect(Reading(kind: .disk, value: "9 GB", detail: "", fraction: 0).menuBarText == "9 GB")
    }
}

struct BatteryHealthTests {
    @Test func maximumCapacityIsTodaysFullChargeOverTheDesign() {
        #expect(BatteryReading.maximumCapacity(fullCharge: 5529, design: 6249) == 88)
        #expect(BatteryReading.maximumCapacity(fullCharge: 6400, design: 6249) == 100)
        #expect(BatteryReading.maximumCapacity(fullCharge: 5529, design: 0) == nil)
    }

    @Test func theHealthLineShowsWhatIsKnown() {
        var battery = BatteryReading(level: 80, isCharging: false, isOnAC: true, hasBattery: true)
        #expect(battery.reading?.note == nil)
        battery.cycleCount = 78
        #expect(battery.reading?.note == "78 cycles")
        battery.maximumCapacity = 88
        #expect(battery.reading?.note == "Maximum capacity 88% · 78 cycles")
    }
}

@MainActor
struct ToolIdentityTests {
    @Test func theIdIsStableBecauseItNamesPersistedState() {
        // Changing it would silently orphan a person's settings, so this pins the string.
        #expect(VitalsTool.id.rawValue == "vitals")
    }
}

@MainActor
struct VitalsMenuBarTests {
    private func freshSettings() -> ToolSettings {
        let name = "vitals." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ToolSettings(tool: VitalsTool.id, defaults: defaults)
    }

    @Test func diskAloneIsInTheMenuBarByDefault() {
        let tool = VitalsTool(settings: freshSettings())
        #expect(tool.menuBarKinds == [.disk])
        #expect(tool.statusIcons().map(\.id) == ["disk"])
    }

    @Test func eachReadingThatIsOnGetsItsOwnIconInThePanelsOrder() {
        let tool = VitalsTool(settings: freshSettings())
        tool.setInMenuBar(.disk, true)
        tool.setInMenuBar(.cpu, true)
        tool.setInMenuBar(.memory, true)
        // The tool is not started, so CPU has no reading yet: its icon is there, without a number.
        #expect(tool.statusIcons().map(\.id) == ["cpu", "memory", "disk"])
    }

    @Test func theLastIconCannotBeTurnedOff() {
        let tool = VitalsTool(settings: freshSettings())
        tool.setInMenuBar(.disk, false)
        #expect(tool.menuBarKinds == [.disk])
        tool.setInMenuBar(.memory, true)
        tool.setInMenuBar(.disk, false)
        #expect(tool.menuBarKinds == [.memory])
    }

    @Test func theChoiceSurvivesARelaunch() {
        let settings = freshSettings()
        let tool = VitalsTool(settings: settings)
        tool.setInMenuBar(.cpu, true)
        tool.setInMenuBar(.disk, false)
        tool.showsValueInMenuBar = false
        let relaunched = VitalsTool(settings: settings)
        #expect(relaunched.menuBarKinds == [.cpu])
        #expect(!relaunched.showsValueInMenuBar)
    }

    @Test func theSwitchesRedrawWhenTheyChange() {
        let tool = VitalsTool(settings: freshSettings())
        final class Flag: @unchecked Sendable { var raised = 0 }
        let flag = Flag()
        withObservationTracking { _ = tool.menuBarKinds } onChange: { flag.raised += 1 }
        tool.setInMenuBar(.cpu, true)
        withObservationTracking { _ = tool.showsValueInMenuBar } onChange: { flag.raised += 1 }
        tool.showsValueInMenuBar = false
        #expect(flag.raised == 2)
    }
}
