import Foundation
import Testing
@testable import LumosTool
import PrismKit

@MainActor
struct TimeTextTests {
    @Test func compactFitsTheMenuBar() {
        #expect(TimeText.compact(42) == "42s")
        #expect(TimeText.compact(42 * 60) == "42m")
        #expect(TimeText.compact(3600 + 2 * 60) == "1:02")
    }

    @Test func remainingReadsLikeProse() {
        #expect(TimeText.remaining(59) == LumosStrings.lessThanAMinute)
        #expect(TimeText.remaining(41 * 60) == "41 min")
        #expect(TimeText.remaining(3600 + 2 * 60) == "1 hr 2 min")
        #expect(TimeText.remaining(2 * 3600) == "2 hr")
    }
}
