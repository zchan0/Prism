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
    var remaining: TimeInterval?
    var length: SessionLength = .forever
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
            remaining: model.remaining,
            length: model.engine.length,
            keepsDisplayAwake: model.preferences.keepsDisplayAwake,
            keepsAwakeWithLidClosed: model.preferences.keepsAwakeWithLidClosed,
            lidBusy: model.lid.isBusy,
            battery: model.battery.snapshot,
            lowBatteryThreshold: model.preferences.lowBatteryThreshold.rawValue,
            errorMessage: model.lastError
        )
    }
}

/// The awake tool's controls: the whole quick panel, and the top of its tab in the hub.
struct ControlsView: View {
    let content: ControlsContent
    let actions: ControlsActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            status
            durations
                .padding(.top, 12)
                .padding(.bottom, 6)
            if let batteryNote {
                HStack(spacing: 6) {
                    Image(systemName: "battery.25percent")
                        .font(.system(size: 10.5))
                    Text(batteryNote)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .padding(.bottom, 4)
            }
            details
            if let errorMessage = content.errorMessage {
                banner(errorMessage)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 15, weight: .medium))
                .symbolPrimaryLayerOnly(
                    !content.isAwake,
                    color: Color(nsColor: content.isAwake ? Palette.sun : Palette.ink3)
                )
                .frame(width: 20)
            HStack(spacing: 5) {
                Text(content.isAwake ? LumosStrings.keepingAwake : LumosStrings.sleeping)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                Text(verbatim: "·")
                Text(statusDetail)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(Color(nsColor: Palette.ink3))
            .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var statusDetail: String {
        guard content.isAwake else { return LumosStrings.maySleep }
        guard let remaining = content.remaining else { return LumosStrings.noTimer }
        return LumosStrings.inTime(TimeText.remaining(remaining))
    }

    private var durations: some View {
        HStack(spacing: 6) {
            ForEach(SessionLength.displayOrder) { length in
                DurationButton(
                    title: LumosStrings.lengthCompact(length),
                    isSelected: content.length == length && content.isAwake
                ) {
                    actions.setLength(length)
                }
                .help(LumosStrings.lengthName(length))
            }
            Button(action: actions.toggle) {
                Image(systemName: content.isAwake ? "moon.zzz.fill" : "wand.and.stars")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: content.isAwake ? Palette.onWarm : Palette.ink2))
                    .frame(width: 28, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: content.isAwake ? Palette.sun : Palette.chip))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(content.isAwake ? LumosStrings.stop : LumosStrings.keepAwake)
            .accessibilityLabel(content.isAwake ? LumosStrings.stop : LumosStrings.keepAwake)
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            PanelRow(
                LumosStrings.keepsDisplayAwake,
                symbol: "display",
                note: LumosStrings.keepsDisplayAwakeNote
            ) {
                PanelSwitch(isOn: Binding(
                    get: { content.keepsDisplayAwake },
                    set: { actions.setKeepsDisplayAwake($0) }
                ))
            }
            PanelDivider().padding(.leading, 28)
            PanelRow(
                LumosStrings.lidClosed,
                symbol: "laptopcomputer",
                note: content.lidBusy ? LumosStrings.lidChanging : LumosStrings.lidClosedNote
            ) {
                PanelSwitch(isOn: Binding(
                    get: { content.keepsAwakeWithLidClosed },
                    set: { newValue in
                        if newValue {
                            actions.confirmLidChange()
                        } else {
                            actions.setKeepsAwakeWithLidClosed(false)
                        }
                    }
                ))
                .disabled(content.lidBusy)
            }
        }
    }

    /// Only what the low battery rule means for this session; the charge itself is in Vitals.
    private var batteryNote: String? {
        guard content.battery.isOnBattery, content.lowBatteryThreshold > 0 else { return nil }
        return LumosStrings.lowBatteryStopsAt(content.lowBatteryThreshold)
    }

    private func banner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(nsColor: Palette.ink2))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: Palette.chip)))
    }
}

private struct DurationButton: View {
    let title: String
    let isSelected: Bool
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var fill: Color {
        if isSelected { return Color(nsColor: Palette.sun) }
        return Color(nsColor: hovered ? Palette.rowHover : Palette.chip)
    }

    private var ink: Color {
        isSelected ? Color(nsColor: Palette.onWarm) : Color(nsColor: Palette.chipInk)
    }
}
