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
                        .panelInk(.tertiary)
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
                    .panelInk(reading.isTight ? .fixed(Palette.warning) : .tertiary)
                    .frame(width: 16)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.kind.name)
                        .font(PanelFont.title)
                        .panelInk(.secondary)
                    Spacer(minLength: 6)
                    Text(reading.value)
                        .font(PanelFont.name)
                        .monospacedDigit()
                        .panelInk(.primary)
                    Text(reading.detail)
                        .font(PanelFont.note)
                        .monospacedDigit()
                        .panelInk(.tertiary)
                }
                .lineLimit(1)
            }
            LevelBar(fraction: reading.fraction, color: reading.isTight ? Palette.warning : Palette.meter)
            if let note = reading.note {
                Text(note)
                    .font(PanelFont.note)
                    .monospacedDigit()
                    .panelInk(.tertiary)
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
