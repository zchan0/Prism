import Foundation
import Testing
@testable import LumosTool
import PrismKit

@MainActor
struct PreferencesTests {
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func newInstallDefaultsToUntilStopped() {
        let defaults = makeDefaults()
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.lastLength == .forever)
    }

    @Test func aPickedLengthSurvivesARelaunch() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Preferences(defaults: defaults).lastLength = .oneHour
        #expect(Preferences(defaults: defaults).lastLength == .oneHour)
    }
}
