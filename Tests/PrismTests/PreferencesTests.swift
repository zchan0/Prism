import Foundation
import Testing
@testable import AwakeTool
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

    @Test func olderBuildsThatStoredThirtyMinutesAreMovedOverOnce() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        // What the first build wrote: a 30 minute default, and no migration marker.
        defaults.set(SessionLength.thirtyMinutes.rawValue, forKey: "lastLength")

        #expect(Preferences(defaults: defaults).lastLength == .forever)
        // A length picked after the migration is kept.
        let preferences = Preferences(defaults: defaults)
        preferences.lastLength = .twoHours
        #expect(Preferences(defaults: defaults).lastLength == .twoHours)
    }

    @Test func aPickedLengthSurvivesARelaunch() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Preferences(defaults: defaults).lastLength = .oneHour
        #expect(Preferences(defaults: defaults).lastLength == .oneHour)
    }
}
