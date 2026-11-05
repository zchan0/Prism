import AppKit
import Observation
import PrismKit
import SwiftUI

@MainActor
@Observable
final class QuickPanelModel {
    var registration: ToolRegistration?
    /// Bumped on every opening, so the tool's controls are built fresh and their `onAppear` runs again.
    var opening = 0
    var revision = 0
}

/// The panel a click on a tool's menu bar icon opens: the tool's controls, and a way into the hub.
@MainActor
final class QuickPanelController {
    static let width: CGFloat = 320

    var onOpenHub: ((ToolID) -> Void)?

    private let model = QuickPanelModel()
    private let panel: FloatingPanelController

    init() {
        panel = FloatingPanelController(width: Self.width, content: AnyView(EmptyView()))
        panel.setContent(AnyView(QuickPanelView(
            model: model,
            openHub: { [weak self] id in self?.onOpenHub?(id) },
            onHeight: { [weak self] height in self?.panel.setContentHeight(height) }
        )))
    }

    var isShown: Bool { panel.isShown }
    /// The tool whose controls are on screen, or nil while the panel is closed.
    var shownTool: ToolID? { isShown ? model.registration?.id : nil }

    func show(_ registration: ToolRegistration, below button: NSStatusBarButton) {
        prepare(registration)
        panel.show(below: button)
    }

    func show(_ registration: ToolRegistration, anchoredAt rect: NSRect, on screen: NSScreen) {
        prepare(registration)
        panel.show(anchoredAt: rect, placement: .below, on: screen)
    }

    func hide() {
        panel.hide()
    }

    func refreshIfVisible() {
        guard isShown else { return }
        model.revision += 1
    }

    #if DEBUG
    var window: NSWindow { panel.window }
    #endif

    private func prepare(_ registration: ToolRegistration) {
        model.registration = registration
        model.opening += 1
    }
}

struct QuickPanelView: View {
    let model: QuickPanelModel
    let openHub: @MainActor (ToolID) -> Void
    let onHeight: @MainActor (CGFloat) -> Void

    var body: some View {
        let _ = model.revision
        VStack(spacing: 0) {
            if let registration = model.registration {
                registration.tool.controlsView()
                    .id(model.opening)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                PanelDivider()
                footer(registration)
            }
        }
        .frame(width: QuickPanelController.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
    }

    private func footer(_ registration: ToolRegistration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: registration.tool.symbolName)
                .font(.system(size: 11))
                .symbolPrimaryLayerOnly(registration.tool.symbolPrimaryLayerOnly, color: Color(nsColor: Palette.ink3))
                .frame(width: 16)
            Text(registration.tool.title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
            PanelIconButton(symbol: "triangle", title: Strings.openHub) {
                openHub(registration.id)
            }
        }
        .foregroundStyle(Color(nsColor: Palette.ink3))
        .padding(.leading, 14)
        .padding(.trailing, 7)
        .frame(height: 36)
    }
}
