import AppKit
import Observation
import PrismKit
import SwiftUI

struct ControlsActions {
    var toggle: @MainActor () -> Void
    var setLength: @MainActor (SessionLength) -> Void
    var setKeepsDisplayAwake: @MainActor (Bool) -> Void
    var setKeepsAwakeWithLidClosed: @MainActor (Bool) -> Void
    var confirmLidChange: @MainActor () -> Void
}

/// Reads the model inside its own body, so SwiftUI observes it and the controls follow the session on their own.
struct LiveControlsView: View {
    let model: AppModel
    let actions: ControlsActions

    var body: some View {
        ControlsView(content: ControlsContent(model: model), actions: actions)
    }
}

/// What the controls need from the model, flattened so the view can be previewed without a live engine.
struct ControlsContent: Equatable {
    var isAwake: Bool = false
    var length: SessionLength = .forever
    var remaining: TimeInterval?
    var keepsDisplayAwake = true
    var keepsAwakeWithLidClosed = false
    var lidBusy = false
    var battery = BatterySnapshot.unknown
    var lowBatteryThreshold = 20
    var errorMessage: String?
}

extension ControlsContent {
    @MainActor
    init(model: AppModel) {
        self.init(
            isAwake: model.isAwake,
            length: model.engine.length,
            remaining: model.remaining,
            keepsDisplayAwake: model.preferences.keepsDisplayAwake,
            keepsAwakeWithLidClosed: model.preferences.keepsAwakeWithLidClosed,
            lidBusy: model.lid.isBusy,
            battery: model.battery.snapshot,
            lowBatteryThreshold: model.preferences.lowBatteryThreshold.rawValue,
            errorMessage: model.lastError
        )
        #if DEBUG
        if model.showsNotesForDebug {
            battery = BatterySnapshot(hasBattery: true, level: 64)
            lowBatteryThreshold = 20
            errorMessage = LumosStrings.adminPasswordRequired
        }
        #endif
    }

    /// "29 min left" while counting down, "Awake" until stopped, "Off" otherwise.
    var title: String {
        guard isAwake else { return Strings.off }
        return remaining.map { LumosStrings.inTime(TimeText.remaining($0)) } ?? LumosStrings.awake
    }

    var subtitle: String {
        guard isAwake else { return LumosStrings.sleepsAsUsual }
        return remaining == nil ? LumosStrings.untilTurnedOff : LumosStrings.keepingThisMacAwake
    }
}

/// The awake tool's controls: the body of its panel, and the top of its page in the Prism window.
struct ControlsView: View {
    let content: ControlsContent
    let actions: ControlsActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            session
            HStack(spacing: 10) {
                PanelOption(
                    LumosStrings.screen,
                    note: content.keepsDisplayAwake ? LumosStrings.screenStaysOn : LumosStrings.screenCanTurnOff,
                    symbol: "display",
                    isOn: content.keepsDisplayAwake
                ) {
                    actions.setKeepsDisplayAwake(!content.keepsDisplayAwake)
                }
                PanelOption(
                    LumosStrings.lidClosedOption,
                    note: lidNote,
                    symbol: "laptopcomputer",
                    isOn: content.keepsAwakeWithLidClosed
                ) {
                    if content.keepsAwakeWithLidClosed {
                        actions.setKeepsAwakeWithLidClosed(false)
                    } else {
                        actions.confirmLidChange()
                    }
                }
                .disabled(content.lidBusy)
            }
            if batteryNote != nil || content.errorMessage != nil {
                PanelCard {
                    if let batteryNote {
                        note(batteryNote, symbol: "battery.25percent")
                    }
                    if let errorMessage = content.errorMessage {
                        if batteryNote != nil {
                            PanelDivider.inCard
                        }
                        note(errorMessage, symbol: "exclamationmark.triangle.fill")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var session: some View {
        PanelCard(tint: .lumos, isTinted: content.isAwake) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(PanelFont.hero)
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink))
                            .contentTransition(reduceMotion ? .opacity : .numericText())
                            .animation(.default, value: content.title)
                        Text(content.subtitle)
                            .font(PanelFont.note)
                            .foregroundStyle(Color(nsColor: Palette.ink2))
                    }
                    .lineLimit(1)
                    Spacer(minLength: 8)
                    PanelSwitch(
                        isOn: Binding(
                            get: { content.isAwake },
                            set: { isOn in
                                if isOn != content.isAwake { actions.toggle() }
                            }
                        ),
                        size: .large
                    )
                    .accessibilityLabel(LumosStrings.keepThisMacAwake)
                }
                PanelSegmented(
                    SessionLength.displayOrder.map { length in
                        PanelSegmented.Item(
                            length,
                            title: LumosStrings.lengthCompact(length),
                            accessibilityLabel: LumosStrings.lengthName(length),
                            help: LumosStrings.lengthName(length)
                        )
                    },
                    selection: content.isAwake ? content.length : nil
                ) { length in
                    actions.setLength(length)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(LumosStrings.howLong)
            }
            .padding(14)
        }
    }

    private var lidNote: String {
        if content.lidBusy { return LumosStrings.lidChanging }
        return content.keepsAwakeWithLidClosed ? LumosStrings.lidStaysAwake : LumosStrings.lidSleeps
    }

    /// Only what the low battery rule means for this session; the charge itself is in Vitals.
    private var batteryNote: String? {
        guard content.battery.isOnBattery, content.lowBatteryThreshold > 0 else { return nil }
        return LumosStrings.lowBatteryStopsAt(content.lowBatteryThreshold)
    }

    private func note(_ text: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .frame(width: 16)
            Text(text)
                .font(PanelFont.note)
                .foregroundStyle(Color(nsColor: Palette.ink2))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: PanelRowMetrics.minHeight - 16, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
