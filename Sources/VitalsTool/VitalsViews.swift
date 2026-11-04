import PrismKit
import SwiftUI

/// The tool's row in the hub: every reading with a bar, so the menu bar number is not the only answer.
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
                        Text(name(of: reading.kind))
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
                }
            }
            Text(VitalsStrings.includesReclaimable)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func name(of kind: Reading.Kind) -> String {
        switch kind {
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
        VStack(alignment: .leading, spacing: 6) {
            Picker(VitalsStrings.shownInMenuBar, selection: Binding(
                get: { tool.shown },
                set: { tool.shown = $0 }
            )) {
                ForEach(Reading.Kind.allCases, id: \.self) { kind in
                    Text(name(of: kind)).tag(kind)
                }
            }
            .pickerStyle(.menu)
            Toggle(VitalsStrings.showValue, isOn: Binding(
                get: { tool.showsValueInMenuBar },
                set: { tool.showsValueInMenuBar = $0 }
            ))
            Text(VitalsStrings.refreshNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func name(of kind: Reading.Kind) -> String {
        switch kind {
        case .disk: VitalsStrings.diskName
        case .memory: VitalsStrings.memoryName
        case .battery: VitalsStrings.batteryName
        }
    }
}
