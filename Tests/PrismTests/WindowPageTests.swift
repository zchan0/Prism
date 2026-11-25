import PrismKit
import Testing
@testable import Prism

@MainActor
struct WindowPageTests {
    private let lumos = ToolID("lumos")
    private let vitals = ToolID("vitals")

    private func model() -> PrismWindowModel {
        PrismWindowModel(toolIDs: [lumos, vitals])
    }

    @Test func theWindowStartsOnTheFirstTool() {
        #expect(model().page == .tool(lumos))
        #expect(PrismWindowModel(toolIDs: []).page == .general)
    }

    @Test func anOpeningOnAToolShowsItsPage() {
        let window = model()
        window.open(on: .tool(vitals))
        #expect(window.page == .tool(vitals))
        window.open(on: .general)
        #expect(window.page == .general)
    }

    @Test func anOpeningWithoutAPageShowsThePageShownLast() {
        let window = model()
        window.open(on: .tool(vitals))
        window.go(to: .general)
        window.open(on: nil)
        #expect(window.page == .general)
    }

    @Test func aToolTheWindowDoesNotKnowShowsGeneral() {
        let window = model()
        window.open(on: .tool(ToolID("gone")))
        #expect(window.page == .general)
        window.go(to: .tool(lumos))
        window.go(to: .tool(ToolID("gone")))
        #expect(window.page == .general)
    }
}
