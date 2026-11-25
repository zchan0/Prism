import PrismKit
import SwiftUI

/// Every reading with a bar, so the menu bar number is not the only answer: the body of the panel, and the top of
/// the tool's page in the Prism window.
struct VitalsPanelView: View {
    let tool: VitalsTool

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                if tool.readings.isEmpty {
                    Text(VitalsStrings.unavailable)
                        .font(PanelFont.note)
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                }
                ForEach(tool.readings) { reading in
                    ReadingView(reading: reading)
                }
            }
            .padding(14)
        }
        .onAppear { tool.refresh() }
    }
}

private struct ReadingView: View {
    let reading: Reading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: reading.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: reading.isTight ? Palette.warning : Palette.ink3))
                    .frame(width: 16)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.kind.name)
                        .font(PanelFont.title)
                        .foregroundStyle(Color(nsColor: Palette.ink2))
                    Spacer(minLength: 6)
                    Text(reading.value)
                        .font(PanelFont.name)
                        .monospacedDigit()
                        .foregroundStyle(Color(nsColor: Palette.ink))
                    Text(reading.detail)
                        .font(PanelFont.note)
                        .monospacedDigit()
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                }
                .lineLimit(1)
            }
            LevelBar(fraction: reading.fraction, isTight: reading.isTight)
            if let note = reading.note {
                Text(note)
                    .font(PanelFont.note)
                    .monospacedDigit()
                    .foregroundStyle(Color(nsColor: Palette.ink3))
            }
        }
    }
}

extension Reading.Kind {
    var name: String {
        switch self {
        case .cpu: VitalsStrings.cpuName
        case .disk: VitalsStrings.diskName
        case .memory: VitalsStrings.memoryName
        case .battery: VitalsStrings.batteryName
        }
    }
}

struct LevelBar: View {
    let fraction: Double
    let isTight: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: Palette.well))
                Capsule()
                    .fill(Color(nsColor: isTight ? Palette.warning : Palette.meter))
                    .frame(width: max(4, proxy.size.width * fraction))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The rows the Prism window's Menu Bar card adds for Vitals: an icon for each reading, and the number next to it.
struct VitalsMenuBarSettingsView: View {
    let tool: VitalsTool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(menuBarChoices, id: \.self) { kind in
                PanelRow(kind.name, symbol: kind.symbolName) {
                    PanelSwitch(isOn: Binding(
                        get: { tool.menuBarKinds.contains(kind) },
                        set: { tool.setInMenuBar(kind, $0) }
                    ))
                    .disabled(tool.menuBarKinds == [kind])
                    .accessibilityLabel(kind.name)
                }
                PanelDivider.inCard
            }
            PanelRow(VitalsStrings.showValue) {
                PanelSwitch(isOn: Binding(
                    get: { tool.showsValueInMenuBar },
                    set: { tool.showsValueInMenuBar = $0 }
                ))
                .accessibilityLabel(VitalsStrings.showValue)
            }
        }
    }

    /// A Mac without a battery has no battery icon to offer.
    private var menuBarChoices: [Reading.Kind] {
        Reading.Kind.allCases.filter { $0 != .battery || tool.isAvailable(.battery) }
    }
}
