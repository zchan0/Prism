import PrismKit
import SwiftUI

/// The looks being tried for Liquid Glass, at the bottom of General until one is picked.
struct ExperimentsSection: View {
    let look: LookSettings

    var body: some View {
        PanelSection(Strings.experiments, note: Strings.experimentsNote) {
            PanelRow(Strings.lookGrouping) {
                PanelPopUp(
                    selection: Binding(get: { look.grouping }, set: { look.setGrouping($0) }),
                    options: PanelGrouping.allCases,
                    title: \.title
                )
                .accessibilityLabel(Strings.lookGrouping)
            }
            PanelDivider.inCard
            PanelRow(Strings.lookInk) {
                PanelPopUp(
                    selection: Binding(get: { look.ink }, set: { look.setInk($0) }),
                    options: PanelInkStyle.allCases,
                    title: \.title
                )
                .accessibilityLabel(Strings.lookInk)
            }
            PanelDivider.inCard
            PanelRow(Strings.lookBackground) {
                PanelPopUp(
                    selection: Binding(get: { look.background }, set: { look.setBackground($0) }),
                    options: PanelBackground.allCases,
                    title: \.title
                )
                .accessibilityLabel(Strings.lookBackground)
            }
            PanelDivider.inCard
            PanelRow(Strings.lookSidebar, note: Strings.lookSidebarNote) {
                PanelPopUp(
                    selection: Binding(get: { look.sidebar }, set: { look.setSidebar($0) }),
                    options: WindowSidebar.allCases,
                    title: \.title
                )
                .accessibilityLabel(Strings.lookSidebar)
            }
        }
    }
}

private extension PanelGrouping {
    var title: String {
        switch self {
        case .cards: Strings.lookCards
        case .plates: Strings.lookPlates
        case .bare: Strings.lookBare
        }
    }
}

private extension PanelInkStyle {
    var title: String {
        switch self {
        case .palette: Strings.lookPalette
        case .system: Strings.lookSystem
        }
    }
}

private extension PanelBackground {
    var title: String {
        switch self {
        case .glass: Strings.lookGlass
        case .material: Strings.lookMaterial
        }
    }
}

private extension WindowSidebar {
    var title: String {
        switch self {
        case .custom: Strings.lookCustom
        case .system: Strings.lookSystem
        }
    }
}
