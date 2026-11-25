import PrismKit
import SwiftUI

/// The awake tool's settings, shown under its controls on its page in the Prism window.
struct LumosSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        PanelSection(LumosStrings.sessions) {
            PanelRow(LumosStrings.lengthPicker) {
                PanelPopUp(selection: $preferences.lastLength, options: SessionLength.displayOrder) { length in
                    LumosStrings.lengthName(length)
                }
            }
            PanelDivider.inCard
            PanelRow(LumosStrings.lowBatteryStops) {
                PanelPopUp(selection: $preferences.lowBatteryThreshold, options: LowBatteryThreshold.allCases) { threshold in
                    threshold == .off ? LumosStrings.lowBatteryOff : LumosStrings.percent(threshold.rawValue)
                }
            }
            PanelDivider.inCard
            PanelRow(LumosStrings.notifiesWhenTimerEnds) {
                PanelSwitch(isOn: $preferences.notifiesWhenTimerEnds)
            }
            PanelDivider.inCard
            PanelRow(LumosStrings.notifiesWhenBatteryLow) {
                PanelSwitch(isOn: $preferences.notifiesWhenBatteryLow)
            }
        }
    }
}

/// The row the Prism window's Menu Bar card adds for Lumos.
struct LumosMenuBarSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        PanelRow(LumosStrings.menuBarTime) {
            PanelSwitch(isOn: $preferences.showsTimeInMenuBar)
        }
    }
}
