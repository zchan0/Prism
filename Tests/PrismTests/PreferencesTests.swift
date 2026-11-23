import Foundation
import Testing
@testable import LumosTool
import PrismKit

@MainActor
struct PreferencesTests {
    @Test func newInstallDefaultsToUntilStopped() {
        let defaults = MemoryDefaults()
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.lastLength == .forever)
    }

    @Test func aPickedLengthSurvivesARelaunch() {
        let defaults = MemoryDefaults()
        Preferences(defaults: defaults).lastLength = .oneHour
        #expect(Preferences(defaults: defaults).lastLength == .oneHour)
    }
}
