import Foundation
import PrismKit
import Testing

@MainActor
struct LookSettingsTests {
    @Test func everyLookStartsAsPrismLookedBefore() {
        let look = LookSettings(defaults: MemoryDefaults())
        #expect(look.grouping == .cards)
        #expect(look.ink == .palette)
        #expect(look.background == .glass)
        #expect(look.sidebar == .custom)
        #expect(look.panel == .window)
    }

    @Test func aPickedLookIsKept() {
        let defaults = MemoryDefaults()
        let look = LookSettings(defaults: defaults)
        look.setGrouping(.bare)
        look.setInk(.system)
        look.setBackground(.material)
        look.setSidebar(.system)

        let reloaded = LookSettings(defaults: defaults)
        #expect(reloaded.grouping == .bare)
        #expect(reloaded.ink == .system)
        #expect(reloaded.background == .material)
        #expect(reloaded.sidebar == .system)
        #expect(reloaded.panel == PanelLook(grouping: .bare, ink: .system))
        #expect(defaults.string(forKey: "shell.look.grouping") == "bare")
        #expect(defaults.string(forKey: "shell.look.ink") == "system")
        #expect(defaults.string(forKey: "shell.look.panelBackground") == "material")
        #expect(defaults.string(forKey: "shell.look.sidebar") == "system")
    }

    @Test func anUnknownSavedLookFallsBackToTheDefault() {
        let defaults = MemoryDefaults()
        for key in ["shell.look.grouping", "shell.look.ink", "shell.look.panelBackground", "shell.look.sidebar"] {
            defaults.set("frosted", forKey: key)
        }
        let look = LookSettings(defaults: defaults)
        #expect(look.grouping == .cards)
        #expect(look.ink == .palette)
        #expect(look.background == .glass)
        #expect(look.sidebar == .custom)
    }

    @Test func overridesReplaceTheSavedLookWithoutSavingIt() {
        let defaults = MemoryDefaults()
        let look = LookSettings(defaults: defaults, overrides: "plates+system+material+system")
        #expect(look.grouping == .plates)
        #expect(look.ink == .system)
        #expect(look.background == .material)
        #expect(look.sidebar == .system)
        #expect(defaults.dictionaryRepresentation().isEmpty)

        let partial = LookSettings(defaults: defaults, overrides: "bare")
        #expect(partial.grouping == .bare)
        #expect(partial.ink == .palette)
        #expect(partial.sidebar == .custom)
    }

    @Test func onlyPartsOnTheGlassBecomeSeeThrough() {
        #expect(!PanelLook.window.isTranslucent)
        #expect(PanelLook(grouping: .plates, ink: .palette).isTranslucent)
        #expect(PanelLook(grouping: .bare, ink: .system).isTranslucent)
    }
}
