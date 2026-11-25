import Foundation
import Testing
@testable import LumosTool

@MainActor
struct LumosSummaryTests {
    @Test func aCountdownSaysWhatIsLeftInWords() {
        #expect(LumosTool.summary(isAwake: true, remaining: 29 * 60 + 30) == "29 min left")
        #expect(LumosTool.summary(isAwake: true, remaining: 3600 + 2 * 60) == "1 hr 2 min left")
        #expect(LumosTool.summary(isAwake: true, remaining: 20) == "less than a minute left")
    }

    @Test func untilStoppedSaysAwake() {
        #expect(LumosTool.summary(isAwake: true, remaining: nil) == "Awake")
    }

    @Test func whileTheMacMaySleepItSaysSo() {
        #expect(LumosTool.summary(isAwake: false, remaining: nil) == "Not keeping awake")
        #expect(LumosTool.summary(isAwake: false, remaining: 600) == "Not keeping awake")
    }

    @Test func theCardSaysTheSameAsTheSummaryInItsOwnWords() {
        let counting = ControlsContent(isAwake: true, length: .thirtyMinutes, remaining: 29 * 60 + 30)
        #expect(counting.title == "29 min left")
        #expect(counting.subtitle == "Keeping this Mac awake")
        let forever = ControlsContent(isAwake: true, length: .forever, remaining: nil)
        #expect(forever.title == "Awake")
        #expect(forever.subtitle == "Until you turn it off")
        let off = ControlsContent(isAwake: false, length: .oneHour, remaining: nil)
        #expect(off.title == "Off")
        #expect(off.subtitle == "This Mac sleeps as usual")
    }
}
