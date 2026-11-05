import PrismKit
import SwiftUI

/// Every reading with a bar, so the menu bar number is not the only answer: the quick panel, and the top of the
/// tool's tab in the hub.
struct VitalsPanelView: View {
    let tool: VitalsTool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tool.readings.isEmpty {
                Text(VitalsStrings.unavailable)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
            }
            ForEach(tool.readings) { reading in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: reading.symbolName)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color(nsColor: reading.isTight ? Palette.sunDeep : Palette.ink3))
                            .frame(width: 14)
                        Text(reading.kind.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(nsColor: Palette.ink2))
                        Spacer(minLength: 6)
                        Text(reading.value)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink))
                        Text(reading.detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color(nsColor: Palette.ink3))
                    }
                    LevelBar(fraction: reading.fraction, isTight: reading.isTight)
                    if let note = reading.note {
                        Text(note)
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink3))
                    }
                }
            }
            Text(VitalsStrings.includesReclaimable)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { tool.refresh() }
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
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(nsColor: Palette.chip))
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(nsColor: isTight ? Palette.sunDeep : Palette.ink2))
                    .frame(width: max(2, proxy.size.width * fraction))
            }
        }
        .frame(height: 5)
    }
}

struct VitalsSettingsView: View {
    let tool: VitalsTool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelRow(VitalsStrings.menuBarIcons, note: VitalsStrings.menuBarIconsNote) {
                EmptyView()
            }
            ForEach(menuBarChoices, id: \.self) { kind in
                PanelRow(kind.name, symbol: kind.symbolName) {
                    PanelSwitch(isOn: Binding(
                        get: { tool.menuBarKinds.contains(kind) },
                        set: { tool.setInMenuBar(kind, $0) }
                    ))
                    .disabled(tool.menuBarKinds == [kind])
                }
            }
            PanelDivider()
                .padding(.vertical, 3)
            PanelRow(VitalsStrings.showValue) {
                PanelSwitch(isOn: Binding(
                    get: { tool.showsValueInMenuBar },
                    set: { tool.showsValueInMenuBar = $0 }
                ))
            }
            Text(VitalsStrings.refreshNote)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    /// A Mac without a battery has no battery icon to offer.
    private var menuBarChoices: [Reading.Kind] {
        Reading.Kind.allCases.filter { $0 != .battery || tool.isAvailable(.battery) }
    }
}
