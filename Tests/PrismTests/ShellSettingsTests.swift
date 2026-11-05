import Foundation
import PrismKit
import SwiftUI
import Testing

@MainActor
struct ShellSettingsTests {
    private func fresh() -> UserDefaults {
        let name = "shell." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func registrations() -> [ToolRegistration] {
        // Two stand-ins with the same shape as real tools, so this does not depend on a tool module.
        [ToolRegistration(StubToolA(), defaultPlacement: .ownIcon),
         ToolRegistration(StubToolB(), defaultPlacement: .hubOnly)]
    }

    @Test func aNewToolStartsOn() {
        let shell = ShellSettings(registrations: registrations(), defaults: fresh())
        #expect(shell.isEnabled(ToolID("a")))
        #expect(shell.isEnabled(ToolID("b")))
    }

    @Test func aToolAddedInALaterVersionStartsOn() {
        let defaults = fresh()
        let first = ShellSettings(registrations: registrations(), defaults: defaults)
        first.setEnabled(false, for: ToolID("b"))

        // A tool the person has never seen must not be off just because the enabled set was saved without it.
        let withNewTool = [
            ToolRegistration(StubToolA(), defaultPlacement: .ownIcon),
            ToolRegistration(StubToolB(), defaultPlacement: .hubOnly),
            ToolRegistration(StubToolC(), defaultPlacement: .ownIcon),
        ]
        let shell = ShellSettings(registrations: withNewTool, defaults: defaults)
        #expect(shell.isEnabled(ToolID("a")))
        #expect(!shell.isEnabled(ToolID("b")))
        #expect(shell.isEnabled(ToolID("c")))
    }

    @Test func placementIsRememberedPerTool() {
        let defaults = fresh()
        let shell = ShellSettings(registrations: registrations(), defaults: defaults)
        shell.setPlacement(.hubOnly, for: ToolID("a"))
        shell.setPlacement(.ownIcon, for: ToolID("b"))

        let reloaded = ShellSettings(registrations: registrations(), defaults: defaults)
        #expect(reloaded.placement(of: ToolID("a")) == .hubOnly)
        #expect(reloaded.placement(of: ToolID("b")) == .ownIcon)
    }

    @Test func theDefaultPlacementComesFromTheRegistration() {
        let shell = ShellSettings(registrations: registrations(), defaults: fresh())
        #expect(shell.placement(of: ToolID("a")) == .ownIcon)
        #expect(shell.placement(of: ToolID("b")) == .hubOnly)
    }

    @Test func turningAToolOffKeepsItsPlacement() {
        let defaults = fresh()
        let shell = ShellSettings(registrations: registrations(), defaults: defaults)
        shell.setPlacement(.hubOnly, for: ToolID("a"))
        shell.setEnabled(false, for: ToolID("a"))
        shell.setEnabled(true, for: ToolID("a"))
        #expect(shell.placement(of: ToolID("a")) == .hubOnly)
    }
}

@MainActor
private final class StubTool: Tool {
    // A static id has to be knowable without an instance; the shell reads `type(of: tool).id`.
    static var id: ToolID { ToolID("stub") }
    private let name: String
    init(id: String) { name = id }
    var title: String { name }
    var symbolName: String { "circle" }
    var summary: String { "" }
    func start() {}
    func stop() {}
    func controlsView() -> AnyView { AnyView(EmptyView()) }
}

/// Each stub needs its own identity, and a static property cannot differ per instance, so the registrations built in
/// the tests above share one id. Registering two tools with the same id is exactly what the shell must tolerate
/// enough not to crash, but the tests that care about distinct ids use distinct stub types.
@MainActor
private final class StubToolA: Tool {
    static let id = ToolID("a")
    var title: String { "a" }
    var symbolName: String { "circle" }
    var summary: String { "" }
    func start() {}
    func stop() {}
    func controlsView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private final class StubToolB: Tool {
    static let id = ToolID("b")
    var title: String { "b" }
    var symbolName: String { "circle" }
    var summary: String { "" }
    func start() {}
    func stop() {}
    func controlsView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private final class StubToolC: Tool {
    static let id = ToolID("c")
    var title: String { "c" }
    var symbolName: String { "circle" }
    var summary: String { "" }
    func start() {}
    func stop() {}
    func controlsView() -> AnyView { AnyView(EmptyView()) }
}
