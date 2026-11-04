import AppKit
import Testing
@testable import AwakeTool
import PrismKit

@MainActor
struct QuickPanelTests {
    private let visible = NSRect(x: 0, y: 0, width: 1920, height: 1050)

    @Test func sitsAboveTheSunByDefault() {
        let pet = NSRect(x: 1500, y: 62, width: 144, height: 144)
        let anchor = NSRect(x: pet.midX - QuickPanelController.width / 2, y: pet.maxY, width: QuickPanelController.width, height: 0)
        let frame = PanelController.frame(
            height: QuickPanelController.estimatedHeight,
            from: anchor,
            placement: .above,
            in: visible,
            width: QuickPanelController.width
        )
        #expect(frame.minY == pet.maxY + PanelController.menuBarGap)
        #expect(frame.width == QuickPanelController.width)
        #expect(frame.midX == pet.midX)
    }

    @Test func staysOnScreenWhenThePetIsNearTheRightEdge() {
        let pet = NSRect(x: 1800, y: 200, width: 144, height: 144)
        let anchor = NSRect(x: pet.midX - QuickPanelController.width / 2, y: pet.maxY, width: QuickPanelController.width, height: 0)
        let frame = PanelController.frame(
            height: QuickPanelController.estimatedHeight,
            from: anchor,
            placement: .above,
            in: visible,
            width: QuickPanelController.width
        )
        #expect(frame.maxX <= 1920 - PanelController.screenMargin)
    }

    @Test func theEstimatedHeightMatchesTheRealLayout() {
        // 11 + 18 + 10 + 27 + 12: padding, header, spacing, buttons, padding.
        #expect(QuickPanelController.estimatedHeight == 78)
    }
}
