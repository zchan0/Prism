import PrismKit
import SwiftUI

/// A borderless icon button that lights up under the pointer, for the edges of a panel.
struct PanelIconButton: View {
    let symbol: String
    let title: String
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5))
                .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink2))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? Color(nsColor: Palette.rowHover) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovered = $0 }
    }
}

/// One tab in the hub's tab bar. A title of nil draws the symbol alone.
struct HubTabButton: View {
    let symbol: String
    var primaryLayerOnly = false
    let title: String?
    let accessibilityTitle: String
    let isSelected: Bool
    let isDimmed: Bool
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .symbolPrimaryLayerOnly(primaryLayerOnly, color: ink)
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(ink)
            .padding(.horizontal, title == nil ? 0 : 9)
            .frame(minWidth: 28)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7).fill(fill))
            .contentShape(Rectangle())
            .opacity(isDimmed ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .help(accessibilityTitle)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovered = $0 }
    }

    private var ink: Color {
        Color(nsColor: isSelected ? Palette.ink : Palette.ink3)
    }

    private var fill: Color {
        if isSelected { return Color(nsColor: Palette.chip) }
        return hovered ? Color(nsColor: Palette.rowHover) : .clear
    }
}
