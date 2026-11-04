import AppKit
@testable import DiskTool
import PrismKit
import Testing

struct DiskUsageTests {
    private func usage(total: Int64, available: Int64, important: Int64) -> DiskUsage {
        DiskUsage(total: total, available: available, forImportantUsage: important, volumeName: "Macintosh HD", isInternal: true)
    }

    @Test func showsTheNumberFinderShows() {
        // Finder's "Available" counts purgeable space, so it is the larger of the two macOS reports.
        let disk = usage(total: 494_384_795_648, available: 115_850_162_176, important: 119_158_744_749)
        #expect(disk.shownAvailable == 119_158_744_749)
    }

    @Test func fallsBackWhenTheCapacityIsUnavailable() {
        // macOS returns 0 for the important-usage key on some volumes; 0 would read as a full disk.
        let disk = usage(total: 1000, available: 400, important: 0)
        #expect(disk.shownAvailable == 400)
    }

    @Test func usedIsTheRemainderOfShownAvailable() {
        let disk = usage(total: 1000, available: 400, important: 300)
        #expect(disk.used == 700)
        #expect(disk.usedFraction == 0.7)
    }

    @Test func aVolumeWithNothingInItIsNotAFullBar() {
        let disk = usage(total: 1000, available: 1000, important: 1000)
        #expect(disk.used == 0)
        #expect(disk.usedFraction == 0)
    }

    @Test func nonsenseCapacitiesCannotProduceANegativeBar() {
        let disk = usage(total: 0, available: 99, important: 99)
        #expect(disk.used == 0)
        #expect(disk.usedFraction == 0)
    }

    @Test func readsTheRealBootVolume() {
        let real = DiskUsageReader.read(volumeAt: "/")
        #expect(real != nil)
        #expect((real?.total ?? 0) > 0)
        #expect((real?.shownAvailable ?? 0) > 0)
        #expect((real?.shownAvailable ?? 0) <= (real?.total ?? 0))
    }
}

@MainActor
struct DiskMenuIconTests {
    private let disk = DiskUsage(
        total: 500_000_000_000,
        available: 100_000_000_000,
        forImportantUsage: 120_000_000_000,
        volumeName: "Macintosh HD",
        isInternal: true
    )

    @Test func theIconIsATemplateSoTheMenuBarTintsIt() {
        #expect(DiskMenuIcon.image(usage: disk, showsText: true).isTemplate)
    }

    @Test func showingTheNumberMakesTheItemWider() {
        let withText = DiskMenuIcon.image(usage: disk, showsText: true)
        let withoutText = DiskMenuIcon.image(usage: disk, showsText: false)
        #expect(withText.size.width > withoutText.size.width)
        #expect(withoutText.size.width <= 20)
    }
}

@MainActor
struct ToolNamespacingTests {
    @Test func theToolsHaveDistinctIds() {
        // Two tools sharing an id would share preferences, notifications and the status item's saved position.
        let ids = [DiskTool.id, AwakeToolIDProbe.awake]
        #expect(Set(ids).count == ids.count)
    }

    @Test func idsAreStableBecauseTheyNamePersistedState() {
        // Changing an id would silently orphan a person's settings, so this pins the strings.
        #expect(DiskTool.id.rawValue == "disk")
        #expect(AwakeToolIDProbe.awake.rawValue == "awake")
    }
}

enum AwakeToolIDProbe {
    static let awake = ToolID("awake")
}
