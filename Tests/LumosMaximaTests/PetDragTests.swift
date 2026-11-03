import AppKit
import Testing
@testable import LumosMaxima

/// Dragging the pet by its window has to follow the pointer exactly, which is what these pin down: the same point of
/// the window stays under the cursor, no matter how the window moves underneath it.
struct PetDragTests {
    // The window's top-left is (1000, 100); the pointer grabbed it 70 points in from the left and 70 up from the
    // bottom, so the two agree on where the grab happened.
    private let origin = NSPoint(x: 1000, y: 100)
    private let grab = NSPoint(x: 70, y: 70)
    private var pointerStart: NSPoint { NSPoint(x: origin.x + grab.x, y: origin.y + grab.y) }

    @Test func aSmallWobbleIsStillAClick() {
        var drag = PetDrag(pointerInWindow: grab)
        let nudged = NSPoint(x: pointerStart.x + 3, y: pointerStart.y + 1)
        #expect(drag.origin(forPointer: nudged, currentOrigin: origin) == nil)
        #expect(!drag.didDrag)
    }

    @Test func theWindowFollowsThePointerOneForOne() {
        var drag = PetDrag(pointerInWindow: grab)
        var current = origin
        for step in 1...10 {
            let pointer = NSPoint(x: pointerStart.x + CGFloat(step) * 10, y: pointerStart.y + CGFloat(step) * 5)
            guard let next = drag.origin(forPointer: pointer, currentOrigin: current) else {
                Issue.record("the drag never started")
                return
            }
            current = next
        }
        #expect(drag.didDrag)
        // The pointer travelled (100, 50); so did the window, exactly.
        #expect(current.x == origin.x + 100)
        #expect(current.y == origin.y + 50)
    }

    @Test func itKeepsTrackingAfterTheWindowMoves() {
        var drag = PetDrag(pointerInWindow: grab)
        var current = origin
        for step in 1...20 {
            let pointer = NSPoint(x: pointerStart.x + CGFloat(step) * 7, y: pointerStart.y - CGFloat(step) * 3)
            if let next = drag.origin(forPointer: pointer, currentOrigin: current) {
                current = next
            }
        }
        // Every step re-derives the origin from the pointer alone, so no error accumulates over the drag.
        #expect(current.x == origin.x + 140)
        #expect(current.y == origin.y - 60)
    }

    @Test func aQuickTapNeverStartsADrag() {
        var drag = PetDrag(pointerInWindow: NSPoint(x: 10, y: 10))
        // Mouse down and up in the same spot, which is what a click looks like.
        #expect(drag.origin(forPointer: NSPoint(x: origin.x + 10, y: origin.y + 10), currentOrigin: origin) == nil)
        #expect(!drag.didDrag)
    }

    @Test func aDragBackToTheStartReturnsTheWindowHome() {
        var drag = PetDrag(pointerInWindow: grab)
        var current = origin
        let away = NSPoint(x: pointerStart.x + 200, y: pointerStart.y + 120)
        if let next = drag.origin(forPointer: away, currentOrigin: current) { current = next }
        if let back = drag.origin(forPointer: pointerStart, currentOrigin: current) { current = back }
        #expect(current == origin)
    }
}
