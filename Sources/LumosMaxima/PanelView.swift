import AppKit
import Observation
import SwiftUI

struct PanelActions {
    var toggle: @MainActor () -> Void
    var setLength: @MainActor (SessionLength) -> Void
    var setKeepsDisplayAwake: @MainActor (Bool) -> Void
    var setKeepsAwakeWithLidClosed: @MainActor (Bool) -> Void
    var confirmLidChange: @MainActor () -> Void
    var showSettings: @MainActor () -> Void
    var quit: @MainActor () -> Void
}

struct LivePanelView: View {
    let model: AppModel
    let layout: PanelLayout
    let actions: PanelActions
    let onHeightChange: @MainActor (CGFloat) -> Void

    var body: some View {
        PanelView(model: model, layout: layout, actions: actions, onHeightChange: onHeightChange)
    }
}

/// What the panel needs from the model, flattened so the view can be previewed and snapshotted without a live engine.
struct PanelContent: Equatable {
    var isAwake: Bool = false
    var remaining: TimeInterval?
    var length: SessionLength = .forever
    var elapsed: TimeInterval = 0
    var keepsDisplayAwake = true
    var keepsAwakeWithLidClosed = false
    var lidBusy = false
    var battery = BatterySnapshot.unknown
    var lowBatteryThreshold = 20
    var sunHours: Double = 0
    var petCount = 0
    var errorMessage: String?
}

struct PanelView: View {
    let content: PanelContent
    /// The panel stays alive while hidden, and a running timeline would keep SwiftUI redrawing the sun behind it.
    let animates: Bool
    let actions: PanelActions
    let onHeightChange: @MainActor (CGFloat) -> Void
    @State private var height: CGFloat = 0

    init(content: PanelContent, animates: Bool = true, actions: PanelActions, onHeightChange: @escaping @MainActor (CGFloat) -> Void = { _ in }) {
        self.content = content
        self.animates = animates
        self.actions = actions
        self.onHeightChange = onHeightChange
    }

    init(model: AppModel, layout: PanelLayout, actions: PanelActions, onHeightChange: @escaping @MainActor (CGFloat) -> Void) {
        animates = layout.isShown
        content = PanelContent(
            isAwake: model.isAwake,
            remaining: model.remaining,
            length: model.engine.length,
            elapsed: model.engine.elapsed,
            keepsDisplayAwake: model.preferences.keepsDisplayAwake,
            keepsAwakeWithLidClosed: model.preferences.keepsAwakeWithLidClosed,
            lidBusy: model.lid.isBusy,
            battery: model.battery.snapshot,
            lowBatteryThreshold: model.preferences.lowBatteryThreshold.rawValue,
            sunHours: model.sunHours,
            petCount: model.awakeLog.petCount,
            errorMessage: model.lastError
        )
        self.actions = actions
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color(nsColor: Palette.hair))
            durations
            details
            if let errorMessage = content.errorMessage {
                banner(errorMessage)
            }
            footer
        }
        .frame(width: PanelController.width)
        .overlay(
            RoundedRectangle(cornerRadius: PanelController.cornerRadius)
                .strokeBorder(Color(nsColor: Palette.panelBorder), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PanelController.cornerRadius))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
            height = newHeight
            onHeightChange(newHeight)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(nsColor: Palette.sun).opacity(content.isAwake ? 0.34 : 0.12),
                                Color(nsColor: Palette.sun).opacity(0),
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 46
                        )
                    )
                    .frame(width: 96, height: 96)
                SunPetView(
                    isAwake: content.isAwake,
                    stage: SunStage.stage(for: content.sunHours),
                    animates: animates
                )
                .scaledToFit()
                .scaleEffect(0.64)
                .frame(width: 104, height: 104)
                .allowsHitTesting(false)
            }
            .frame(height: 94)
            .contentShape(Rectangle())
            .onTapGesture(perform: actions.toggle)

            VStack(spacing: 3) {
                Text(content.isAwake ? Strings.keepingAwake : Strings.sleeping)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                Text(statusDetail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var statusDetail: String {
        if !content.isAwake { return Strings.asleepHint }
        if let remaining = content.remaining {
            return Strings.inTime(TimeText.remaining(remaining))
        }
        return Strings.awakeNoTimer(TimeText.remaining(content.elapsed))
    }

    private var durations: some View {
        HStack(spacing: 6) {
            ForEach(SessionLength.displayOrder) { length in
                DurationButton(
                    title: Strings.lengthCompact(length),
                    isSelected: content.length == length && content.isAwake
                ) {
                    actions.setLength(length)
                }
                .help(Strings.lengthName(length))
            }
            Button(action: actions.toggle) {
                Image(systemName: content.isAwake ? "moon.zzz.fill" : "sun.max.fill")
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
            .help(content.isAwake ? Strings.stop : Strings.keepAwake)
            .accessibilityLabel(content.isAwake ? Strings.stop : Strings.keepAwake)
        }
        .padding(.horizontal, 12)
        // The length row needs air under the divider it sits beneath; flush against it looked like a tab bar glued
        // to the header.
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var details: some View {
        VStack(spacing: 0) {
            DetailRow(
                symbol: "display",
                title: Strings.keepsDisplayAwake,
                note: Strings.keepsDisplayAwakeNote
            ) {
                Toggle("", isOn: Binding(
                    get: { content.keepsDisplayAwake },
                    set: { actions.setKeepsDisplayAwake($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            Divider().overlay(Color(nsColor: Palette.hair)).padding(.leading, 34)
            DetailRow(
                symbol: "laptopcomputer",
                title: Strings.lidClosed,
                note: content.lidBusy ? Strings.lidChanging : Strings.lidClosedNote
            ) {
                Toggle("", isOn: Binding(
                    get: { content.keepsAwakeWithLidClosed },
                    set: { newValue in
                        if newValue {
                            actions.confirmLidChange()
                        } else {
                            actions.setKeepsAwakeWithLidClosed(false)
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(content.lidBusy)
            }
            Divider().overlay(Color(nsColor: Palette.hair)).padding(.leading, 34)
            DetailRow(
                symbol: "battery.50percent",
                title: batteryTitle,
                note: batteryNote
            ) {
                BatteryGlyph(snapshot: content.battery)
            }
            Divider().overlay(Color(nsColor: Palette.hair)).padding(.leading, 34)
            DetailRow(
                symbol: "sun.horizon.fill",
                title: Strings.petAwakeToday(TimeText.remaining(content.sunHours * 3600)),
                note: countText
            ) {
                Text(verbatim: "\(content.petCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
            }
        }
        .padding(.horizontal, 12)
    }

    private var batteryTitle: String {
        guard content.battery.hasBattery else { return Strings.noBattery }
        guard let level = content.battery.level else { return Strings.battery }
        return Strings.batteryLevel(level)
    }

    private var batteryNote: String {
        guard content.battery.hasBattery else { return Strings.pluggedIn }
        if content.battery.isPluggedIn { return Strings.pluggedIn }
        if content.battery.level.map({ $0 <= content.lowBatteryThreshold }) == true {
            return Strings.lowBatteryStopsAt(content.lowBatteryThreshold)
        }
        return Strings.onBattery
    }

    private var countText: String {
        if content.sunHours < 0.02 { return Strings.petIdle }
        return Strings.petSessions(content.petCount)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: Palette.chip))
    }

    private var footer: some View {
        HStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(nsImage: MenuBarIcon.image(MenuBarState(mode: content.isAwake ? .forever : .asleep, showsTime: false, holdsDisplay: content.keepsDisplayAwake)))
                    .renderingMode(.template)
                    .frame(width: 16)
                Text(verbatim: "LumosMaxima")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(nsColor: Palette.ink3))
            Spacer(minLength: 0)
            FooterButton(symbol: "gearshape", title: Strings.settings, action: actions.showSettings)
            FooterButton(symbol: "power", title: Strings.quit, action: actions.quit)
        }
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .frame(height: 38)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(nsColor: Palette.hair)).frame(height: 0.5).padding(.horizontal, 12)
        }
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

private struct DetailRow<Accessory: View>: View {
    let symbol: String
    let title: String
    let note: String?
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: Palette.ink))
                    .lineLimit(1)
                if let note {
                    Text(note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            accessory
        }
        .padding(.vertical, 8)
    }
}

private struct BatteryGlyph: View {
    let snapshot: BatterySnapshot

    var body: some View {
        HStack(spacing: 5) {
            if snapshot.hasBattery, let level = snapshot.level {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(nsColor: Palette.ink3), lineWidth: 1)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(fill(for: level))
                            .frame(width: max(2, (proxy.size.width - 4) * CGFloat(level) / 100))
                            .padding(.leading, 2)
                        if snapshot.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(width: 30, height: 14)
                Text("\(level)%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(nsColor: Palette.ink2))
            } else {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: Palette.good))
            }
        }
    }

    private func fill(for level: Int) -> Color {
        if snapshot.isCharging { return Color(nsColor: Palette.good) }
        if level <= 20 { return Color(nsColor: Palette.sunDeep) }
        return Color(nsColor: Palette.ink2)
    }
}

private struct FooterButton: View {
    let symbol: String
    let title: String
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink2))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(hovered ? Color(nsColor: Palette.rowHover) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovered = $0 }
    }
}
