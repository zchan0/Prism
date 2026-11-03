import AppKit
import SwiftUI

struct GeneralSettingsView: View {
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
                    Text(Strings.loginItem)
                    if let note = loginItemNote {
                        Text(note)
                    }
                }
                .disabled(!model.loginItem.isAvailable)
                Toggle(Strings.menuBarTime, isOn: $preferences.showsTimeInMenuBar)
                Toggle(Strings.petLabel, isOn: $preferences.showsPet)
                // Going through the model, not straight to the preference, so a running session re-acquires its
                // assertion instead of keeping the old screen setting until the next start.
                Toggle(isOn: Binding(
                    get: { model.preferences.keepsDisplayAwake },
                    set: { model.setKeepsDisplayAwake($0) }
                )) {
                    Text(Strings.keepsDisplayAwake)
                    Text(Strings.keepsDisplayAwakeNote)
                }
            }

            Section {
                Picker(selection: $preferences.lastLength) {
                    ForEach(SessionLength.allCases) { length in
                        Text(Strings.lengthName(length)).tag(length)
                    }
                } label: {
                    Text(Strings.lengthPicker)
                }
                Picker(selection: $preferences.lowBatteryThreshold) {
                    ForEach(LowBatteryThreshold.allCases) { threshold in
                        Text(threshold == .off ? Strings.lowBatteryOff : Strings.percent(threshold.rawValue)).tag(threshold)
                    }
                } label: {
                    Text(Strings.lowBatteryStops)
                }
            }

            Section(Strings.lidClosed) {
                Toggle(isOn: Binding(
                    get: { model.preferences.keepsAwakeWithLidClosed },
                    set: { newValue in
                        Task {
                            await model.setKeepsAwakeWithLidClosed(newValue)
                            lidError = model.lid.errorMessage
                        }
                    }
                )) {
                    Text(Strings.lidClosed)
                    Text(model.lid.isBusy ? Strings.lidChanging : Strings.lidClosedNote)
                }
                .disabled(model.lid.isBusy)
                if let lidError {
                    Text(lidError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle(Strings.notifiesWhenTimerEnds, isOn: $preferences.notifiesWhenTimerEnds)
                Toggle(Strings.notifiesWhenBatteryLow, isOn: $preferences.notifiesWhenBatteryLow)
            } header: {
                Text(Strings.notifications)
            }

            Section(Strings.shortcuts) {
                LabeledContent(Strings.toggleShortcut) {
                    Text(verbatim: GlobalHotKey.keyName)
                }
            }
        }
        .settingsForm()
    }

    private var loginItemNote: String? {
        if let error = model.loginItem.error { return error }
        return model.loginItem.status == .requiresApproval ? Strings.loginItemNeedsApproval : nil
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
                        remainingText: nil,
                        animates: true,
                        onToggle: {}
                    )
                    .frame(width: SunPetView.size, height: SunPetView.size)
                    .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Strings.petStageNote(SunStage.stage(for: model.sunHours)))
                            .font(.system(size: 13, weight: .medium))
                        Text(Strings.petAwakeToday(TimeText.remaining(model.sunHours * 3600)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Strings.petSessions(model.awakeLog.petCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Toggle(Strings.petLabel, isOn: $preferences.showsPet)
            }

            Section {
                ForEach(SunStage.allCases, id: \.self) { stage in
                    HStack(spacing: 8) {
                        Image(systemName: SunStage.stage(for: model.sunHours) >= stage ? "sun.max.fill" : "sun.max")
                            .foregroundStyle(Color(nsColor: SunStage.stage(for: model.sunHours) >= stage ? Palette.sun : Palette.ink3))
                        Text(Strings.petStageNote(stage))
                            .font(.system(size: 12))
                        Spacer(minLength: 0)
                        Text(stage.requiredHours == 0 ? "—" : "\(Int(stage.requiredHours)) h")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(Strings.petStagesFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(Strings.resetPet, role: .destructive) {
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
            Text(Strings.aboutTagline)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(Strings.version(Self.version))
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
