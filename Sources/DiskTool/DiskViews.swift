import PrismKit
import SwiftUI

/// The tool's row in the hub: a capacity bar and the three numbers, so the summary line is not the only answer.
struct DiskToolView: View {
    let tool: DiskTool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let usage = tool.usage {
                CapacityBar(fraction: usage.usedFraction)
                HStack(spacing: 12) {
                    metric(DiskStrings.capacity, ByteText.compact(usage.total))
                    metric(DiskStrings.used, ByteText.compact(usage.used))
                    metric(DiskStrings.free, ByteText.compact(usage.shownAvailable))
                }
                Text(DiskStrings.forImportantUsage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(DiskStrings.noVolume)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: Palette.ink3))
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: Palette.ink))
        }
    }
}

struct CapacityBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: Palette.chip))
                RoundedRectangle(cornerRadius: 3)
                    .fill(fraction > 0.9 ? Color(nsColor: Palette.sunDeep) : Color(nsColor: Palette.ink2))
                    .frame(width: max(2, proxy.size.width * fraction))
            }
        }
        .frame(height: 6)
    }
}

struct DiskSettingsView: View {
    @Bindable var tool: DiskTool

    var body: some View {
        Form {
            Section {
                LabeledContent(DiskStrings.volume, value: tool.volumePath)
                Toggle(DiskStrings.showFreeSpace, isOn: $tool.showsFreeSpaceInMenuBar)
            } footer: {
                Text(DiskStrings.refreshNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
