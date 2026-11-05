import PrismKit
import SwiftUI

/// The awake tool's settings, shown under its controls on its tab in the hub.
struct LumosSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        VStack(spacing: 0) {
            PanelRow(LumosStrings.menuBarTime) {
                PanelSwitch(isOn: $preferences.showsTimeInMenuBar)
            }
            PanelRow(LumosStrings.lengthPicker) {
                Picker("", selection: $preferences.lastLength) {
                    ForEach(SessionLength.displayOrder) { length in
                        Text(LumosStrings.lengthName(length)).tag(length)
                    }
                }
                .panelMenu()
            }
            PanelRow(LumosStrings.lowBatteryStops) {
                Picker("", selection: $preferences.lowBatteryThreshold) {
                    ForEach(LowBatteryThreshold.allCases) { threshold in
                        Text(threshold == .off ? LumosStrings.lowBatteryOff : LumosStrings.percent(threshold.rawValue))
                            .tag(threshold)
                    }
                }
                .panelMenu()
            }
            PanelRow(LumosStrings.notifiesWhenTimerEnds) {
                PanelSwitch(isOn: $preferences.notifiesWhenTimerEnds)
            }
            PanelRow(LumosStrings.notifiesWhenBatteryLow) {
                PanelSwitch(isOn: $preferences.notifiesWhenBatteryLow)
            }
        }
    }
}
