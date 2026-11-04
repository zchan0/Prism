import AppKit
import SwiftUI
import PrismKit

struct AwakeSettingsView: View {
    let model: AppModel
    @Bindable var preferences: Preferences
    @State private var lidError: String?

    init(model: AppModel) {
        self.model = model
        _preferences = Bindable(model.preferences)
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { model.loginItem.isOn }, set: { model.loginItem.setOn($0) })) {
                    Text(AwakeStrings.loginItem)
                    if let note = loginItemNote {
                        Text(note)
                    }
                }
                .disabled(!model.loginItem.isAvailable)
                Toggle(AwakeStrings.menuBarTime, isOn: $preferences.showsTimeInMenuBar)
                Toggle(AwakeStrings.petLabel, isOn: $preferences.showsPet)
                // Going through the model, not straight to the preference, so a running session re-acquires its
                // assertion instead of keeping the old screen setting until the next start.
                Toggle(isOn: Binding(
                    get: { model.preferences.keepsDisplayAwake },
                    set: { model.setKeepsDisplayAwake($0) }
                )) {
                    Text(AwakeStrings.keepsDisplayAwake)
                    Text(AwakeStrings.keepsDisplayAwakeNote)
                }
            }

            Section {
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
            }

            Section(AwakeStrings.lidClosed) {
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
            }

            Section {
                Toggle(AwakeStrings.notifiesWhenTimerEnds, isOn: $preferences.notifiesWhenTimerEnds)
                Toggle(AwakeStrings.notifiesWhenBatteryLow, isOn: $preferences.notifiesWhenBatteryLow)
            } header: {
                Text(AwakeStrings.notifications)
            }

            Section(AwakeStrings.shortcuts) {
                LabeledContent(AwakeStrings.toggleShortcut) {
                    Text(verbatim: GlobalHotKey.keyName)
                }
            }
        }
        .settingsForm()
    }

    private var loginItemNote: String? {
        if let error = model.loginItem.error { return error }
        return model.loginItem.status == .requiresApproval ? AwakeStrings.loginItemNeedsApproval : nil
    }
}

struct PetSettingsView: View {
    let model: AppModel
    @Bindable var preferences: Preferences

    init(model: AppModel) {
        self.model = model
        _preferences = Bindable(model.preferences)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 18) {
                    SunPetView(
                        isAwake: model.isAwake,
                        stage: SunStage.stage(for: model.sunHours),
                            animates: true
                    )
                    .frame(width: SunPetView.size, height: SunPetView.size)
                    .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AwakeStrings.petStageNote(SunStage.stage(for: model.sunHours)))
                            .font(.system(size: 13, weight: .medium))
                        Text(AwakeStrings.petAwakeToday(TimeText.remaining(model.sunHours * 3600)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AwakeStrings.petSessions(model.awakeLog.petCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Toggle(AwakeStrings.petLabel, isOn: $preferences.showsPet)
            }

            Section {
                ForEach(SunStage.allCases, id: \.self) { stage in
                    HStack(spacing: 8) {
                        Image(systemName: SunStage.stage(for: model.sunHours) >= stage ? "sun.max.fill" : "sun.max")
                            .foregroundStyle(Color(nsColor: SunStage.stage(for: model.sunHours) >= stage ? Palette.sun : Palette.ink3))
                        Text(AwakeStrings.petStageNote(stage))
                            .font(.system(size: 12))
                        Spacer(minLength: 0)
                        Text(stage.requiredHours == 0 ? "—" : "\(Int(stage.requiredHours)) h")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(AwakeStrings.petStagesFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(AwakeStrings.resetPet, role: .destructive) {
                    model.resetPet()
                }
            }
        }
        .settingsForm()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: MenuBarIcon.image(MenuBarState(mode: .forever, showsTime: false, holdsDisplay: true)))
                .resizable()
                .frame(width: 48, height: 48)
            Text(verbatim: "LumosMaxima")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(AwakeStrings.aboutTagline)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(AwakeStrings.version(Self.version))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 26)
        .frame(width: 460)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

private extension View {
    func settingsForm() -> some View {
        formStyle(.grouped)
            .scrollDisabled(true)
            .frame(width: 480)
            .fixedSize(horizontal: false, vertical: true)
    }
}
