import AppKit
import Testing
@testable import LumosMaxima

@MainActor
struct PanelFrameTests {
    private let visible = NSRect(x: 0, y: 0, width: 1920, height: 1056)

    @Test func hangsBelowTheMenuBarFromTheItemsLeftEdge() {
        let anchor = NSRect(x: 1200, y: 1056, width: 180, height: 24)
        #expect(PanelController.frame(height: 400, below: anchor, in: visible) == NSRect(x: 1200, y: 650, width: PanelController.width, height: 400))
    }

    @Test func staysOnScreenNearTheRightEdge() {
        let anchor = NSRect(x: 1800, y: 1056, width: 40, height: 24)
        #expect(PanelController.frame(height: 400, below: anchor, in: visible).maxX == 1912)
    }

    @Test func staysOnScreenNearTheLeftEdge() {
        let anchor = NSRect(x: -20, y: 1056, width: 40, height: 24)
        #expect(PanelController.frame(height: 400, below: anchor, in: visible).minX == 8)
    }

    @Test func shrinksRatherThanRunOffTheBottom() {
        let anchor = NSRect(x: 600, y: 1056, width: 60, height: 24)
        let frame = PanelController.frame(height: 2000, below: anchor, in: visible)
        #expect(frame.minY >= 8)
        #expect(frame.height < 2000)
    }
}

@MainActor
struct MenuBarStateTests {
    @Test func countingShowsTimeOnlyWhenAsked() {
        let state = MenuBarState(mode: .counting(remaining: 1500), showsTime: true, holdsDisplay: true)
        #expect(state.timeText == "25m")
        let hidden = MenuBarState(mode: .counting(remaining: 1500), showsTime: false, holdsDisplay: true)
        #expect(hidden.timeText == nil)
    }

    @Test func foreverHasNoCountdown() {
        #expect(MenuBarState(mode: .forever, showsTime: true, holdsDisplay: false).timeText == nil)
        #expect(!MenuBarState(mode: .forever, showsTime: true, holdsDisplay: false).accessibilityText.isEmpty)
    }
}
