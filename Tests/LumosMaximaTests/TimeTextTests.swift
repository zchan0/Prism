import Foundation
import Testing
@testable import LumosMaxima

@MainActor
struct TimeTextTests {
    @Test func countdownShowsMinutesUnderAnHour() {
        #expect(TimeText.countdown(249) == "4:09")
        #expect(TimeText.countdown(0) == "0:00")
    }

    @Test func countdownAddsHours() {
        #expect(TimeText.countdown(3849) == "1:04:09")
    }

    @Test func countdownRoundsUpSoZeroIsOnlyShownAtTheEnd() {
        #expect(TimeText.countdown(0.4) == "0:01")
    }

    @Test func compactFitsTheMenuBar() {
        #expect(TimeText.compact(42) == "42s")
        #expect(TimeText.compact(42 * 60) == "42m")
        #expect(TimeText.compact(3600 + 2 * 60) == "1:02")
    }

    @Test func remainingReadsLikeProse() {
        #expect(TimeText.remaining(59) == Strings.lessThanAMinute)
        #expect(TimeText.remaining(41 * 60) == "41 min")
        #expect(TimeText.remaining(3600 + 2 * 60) == "1 hr 2 min")
        #expect(TimeText.remaining(2 * 3600) == "2 hr")
    }
}
