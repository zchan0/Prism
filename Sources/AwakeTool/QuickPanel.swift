import AppKit
import Observation
import SwiftUI
import PrismKit

/// What a click on the pet opens: the state, the length buttons, and a way to close it. Everything that is a
/// preference rather than a quick change lives in Settings, which a double click opens.
struct QuickPanelView: View {
    let model: AppModel
    let actions: QuickActions
    let onHeightChange: @MainActor (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            lengths
        }
        .padding(EdgeInsets(top: 11, leading: 12, bottom: 12, trailing: 12))
        .frame(width: QuickPanelController.width)
        // No opaque fill: the panel window is glass underneath, and painting over it would hide the blur the menu
        // bar panel also gets.
        .overlay(
            RoundedRectangle(cornerRadius: QuickPanelController.cornerRadius)
                .strokeBorder(Color(nsColor: Palette.panelBorder), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: QuickPanelController.cornerRadius))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }

    private var isAwake: Bool { model.isAwake }

    private var header: some View {
        HStack(spacing: 7) {
            SunGlyph(isAwake: isAwake)
            Text(isAwake ? AwakeStrings.keepingAwake : AwakeStrings.sleeping)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.ink))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(status)
                .font(.system(size: 11.5, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: Palette.ink3))
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 18)
    }

    private var status: String {
        guard isAwake else { return AwakeStrings.off }
        guard let remaining = model.remaining else { return AwakeStrings.noTimer }
        return TimeText.countdown(remaining)
    }

    private var lengths: some View {
        HStack(spacing: 6) {
            ForEach(SessionLength.displayOrder) { length in
                QuickDurationButton(
                    title: AwakeStrings.lengthCompact(length),
                    isSelected: model.engine.length == length && isAwake
                ) {
                    actions.setLength(length)
                }
                .help(AwakeStrings.lengthName(length))
            }
            QuickCloseButton(action: actions.close)
                .help(AwakeStrings.close)
        }
    }
}

private struct QuickDurationButton: View {
    let title: String
    let isSelected: Bool
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color(nsColor: Palette.onWarm) : Color(nsColor: Palette.chipInk))
                .frame(maxWidth: .infinity)
                .frame(height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color(nsColor: Palette.sun) : Color(nsColor: hovered ? Palette.rowHover : Palette.chip))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct QuickCloseButton: View {
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink3))
                .frame(width: 25, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(nsColor: hovered ? Palette.rowHover : Palette.chip))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AwakeStrings.close)
        .onHover { hovered = $0 }
    }
}

/// A small filled sun, so the strip does not read as a floating row of buttons with nothing to belong to.
private struct SunGlyph: View {
    let isAwake: Bool

    var body: some View {
        Image(systemName: isAwake ? "sun.max.fill" : "sun.min")
            .font(.system(size: 12))
            .foregroundStyle(Color(nsColor: isAwake ? Palette.sun : Palette.ink3))
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

struct QuickActions {
    var setLength: @MainActor (SessionLength) -> Void
    var close: @MainActor () -> Void
}

/// The small panel a click on the pet opens. It is deliberately not `PanelController`: the point of the pet is a
/// quick change of length, and the full panel is available from the menu bar or a double click.
@MainActor
final class QuickPanelController {
    static let width: CGFloat = 268
    static let cornerRadius: CGFloat = 13
    static let screenMargin: CGFloat = 8
    /// Padding + header + gap + button row; only used before the first real measurement.
    static let estimatedHeight: CGFloat = 78

    private let model: AppModel
    private var panel: NSPanel?
    private var anchor: NSRect?
    private var visibleFrame: NSRect?
    private var placement = PanelController.Placement.above
    private var contentHeight: CGFloat = 0
    private var outsideClickMonitor: Any?

    init(model: AppModel) {
        self.model = model
        let actions = QuickActions(
            // A pick starts the session, so no button here ever does nothing.
            setLength: { [weak model] length in model?.setLength(length) },
            close: { [weak self] in self?.hide() }
        )
        let view = QuickPanelView(model: model, actions: actions) { [weak self] height in
            self?.contentHeightChanged(height)
        }
        panel = PanelController.makePanel(rootView: view, width: Self.width, cornerRadius: Self.cornerRadius)
    }

    var isShown: Bool { panel?.isVisible ?? false }

    #if DEBUG
    var windowForDebug: NSWindow? { panel }
    #endif

    func toggle(above petFrame: NSRect, on screen: NSScreen) {
        if isShown {
            hide()
        } else {
            show(above: petFrame, on: screen)
        }
    }

    func show(above petFrame: NSRect, on screen: NSScreen) {
        guard let panel else { return }
        let visible = screen.visibleFrame
        // A pet dragged near the top has no room above it, so the strip drops below instead.
        let roomAbove = visible.maxY - Self.screenMargin - petFrame.maxY
        let roomBelow = petFrame.minY - visible.minY - Self.screenMargin
        // Before the first layout there is no measured height, so the strip's natural height stands in for it.
        let needed = contentHeight > 0 ? contentHeight : Self.estimatedHeight
        placement = roomAbove >= needed || roomAbove >= roomBelow ? .above : .below
        anchor = NSRect(
            x: petFrame.midX - Self.width / 2,
            y: placement == .above ? petFrame.maxY : petFrame.minY,
            width: Self.width,
            height: 0
        )
        visibleFrame = visible
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
        reposition()
        watchOutsideClicks()
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        stopWatchingOutsideClicks()
    }

    private func contentHeightChanged(_ height: CGFloat) {
        contentHeight = height
        DispatchQueue.main.async { [weak self] in self?.reposition() }
    }

    private func reposition() {
        guard let panel, panel.isVisible, let anchor, let visibleFrame, contentHeight > 0 else { return }
        panel.setFrame(
            PanelController.frame(
                height: contentHeight,
                from: anchor,
                placement: placement,
                in: visibleFrame,
                width: Self.width
            ),
            display: true
        )
    }

    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
}
