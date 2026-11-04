import AppKit
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

@MainActor
struct VitalsIconTests {
    private let reading = DiskReading(
        total: 500_000_000_000,
        available: 100_000_000_000,
        forImportantUsage: 120_000_000_000,
        volumeName: "Macintosh HD"
    ).reading

    @Test func theIconIsATemplateSoTheMenuBarTintsIt() {
        #expect(VitalsIcon.image(reading: reading, showsValue: true).isTemplate)
    }

    @Test func showingTheNumberMakesTheItemWider() {
        let withText = VitalsIcon.image(reading: reading, showsValue: true)
        let withoutText = VitalsIcon.image(reading: reading, showsValue: false)
        #expect(withText.size.width > withoutText.size.width)
        #expect(withoutText.size.width <= 20)
    }

    @Test func everyReadingCanDrawItsIcon() {
        for kind in Reading.Kind.allCases {
            let sample = Reading(kind: kind, value: "1", detail: "x", fraction: 0.5)
            #expect(VitalsIcon.image(reading: sample, showsValue: true).size.width > 0)
        }
    }
}

@MainActor
struct ToolIdentityTests {
    @Test func theIdIsStableBecauseItNamesPersistedState() {
        // Changing it would silently orphan a person's settings, so this pins the string.
        #expect(VitalsTool.id.rawValue == "vitals")
    }
}
