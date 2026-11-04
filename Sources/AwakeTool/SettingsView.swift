import AppKit
import PrismKit
import SwiftUI

/// The awake tool's own settings, as plain content inside the shell's form.
///
/// A tool never draws its own `Form`: the shell's form owns the grouping, width and scrolling, and a nested form
/// reports its own preferred size — which is what once stretched the settings window to 1279 points tall.
struct AwakeSettingsView: View {
    let model: AppModel
    @Bindable var preferences: Preferences
    @State private var lidError: String?

    init(model: AppModel) {
        self.model = model
        _preferences = Bindable(model.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(AwakeStrings.menuBarTime, isOn: $preferences.showsTimeInMenuBar)
            // Going through the model, not straight to the preference, so a running session re-acquires its
            // assertion instead of keeping the old screen setting until the next start.
            Toggle(isOn: Binding(
                get: { model.preferences.keepsDisplayAwake },
                set: { model.setKeepsDisplayAwake($0) }
            )) {
                Text(AwakeStrings.keepsDisplayAwake)
                Text(AwakeStrings.keepsDisplayAwakeNote)
            }

            Picker(selection: $preferences.lastLength) {
                ForEach(SessionLength.displayOrder) { length in
                    Text(AwakeStrings.lengthName(length)).tag(length)
                }
            } label: {
                Text(AwakeStrings.lengthPicker)
            }

            Picker(selection: $preferences.lowBatteryThreshold) {
                ForEach(LowBatteryThreshold.allCases) { threshold in
                    Text(threshold == .off ? AwakeStrings.lowBatteryOff : AwakeStrings.percent(threshold.rawValue)).tag(threshold)
                }
            } label: {
                Text(AwakeStrings.lowBatteryStops)
            }

            Toggle(isOn: Binding(
                get: { model.preferences.keepsAwakeWithLidClosed },
                set: { newValue in
                    Task {
                        await model.setKeepsAwakeWithLidClosed(newValue)
                        lidError = model.lid.errorMessage
                    }
                }
            )) {
                Text(AwakeStrings.lidClosed)
                Text(model.lid.isBusy ? AwakeStrings.lidChanging : AwakeStrings.lidClosedNote)
            }
            .disabled(model.lid.isBusy)
            if let lidError {
                Text(lidError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(AwakeStrings.notifiesWhenTimerEnds, isOn: $preferences.notifiesWhenTimerEnds)
            Toggle(AwakeStrings.notifiesWhenBatteryLow, isOn: $preferences.notifiesWhenBatteryLow)
        }
    }
}

/// The pet's page: what the sun has become today, and a way to start over.
struct PetSettingsView: View {
    let model: AppModel
    @Bindable var preferences: Preferences

    init(model: AppModel) {
        self.model = model
        _preferences = Bindable(model.preferences)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                SunPetView(
                    isAwake: model.isAwake,
                    stage: SunStage.stage(for: model.sunHours),
                    animates: true
                )
                .frame(width: SunPetView.size, height: SunPetView.size)
                .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 5) {
                    Text(AwakeStrings.petStageNote(SunStage.stage(for: model.sunHours)))
                        .font(.system(size: 12, weight: .medium))
                    Text(AwakeStrings.petAwakeToday(TimeText.remaining(model.sunHours * 3600)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AwakeStrings.petSessions(model.awakeLog.petCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(AwakeStrings.petLabel, isOn: $preferences.showsPet)

            ForEach(SunStage.allCases, id: \.self) { stage in
                HStack(spacing: 8) {
                    Image(systemName: SunStage.stage(for: model.sunHours) >= stage ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: SunStage.stage(for: model.sunHours) >= stage ? Palette.sun : Palette.ink3))
                        .frame(width: 14)
                    Text(AwakeStrings.petStageNote(stage))
                        .font(.system(size: 11.5))
                    Spacer(minLength: 6)
                    Text(stage.requiredHours == 0 ? "—" : "\(Int(stage.requiredHours)) h")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Text(AwakeStrings.petStagesFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(AwakeStrings.resetPet, role: .destructive) {
                model.resetPet()
            }
        }
    }
}

/// About the tool itself, shown inside its section.
struct AwakeAboutView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: MenuBarIcon.image(MenuBarState(mode: .forever, showsTime: false, holdsDisplay: true)))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "LumosMaxima")
                    .font(.system(size: 12, weight: .medium))
                Text(AwakeStrings.aboutTagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
