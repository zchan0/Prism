import Carbon.HIToolbox
import PrismKit
import Testing
@testable import Prism

@MainActor
@Suite(.serialized)
struct QuickPanelSettingsKeyTests {
    private let commandComma = Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: UInt32(cmdKey), keyName: ",")

    @Test func commandCommaIsHeldOnlyWhileThePanelIsOpen() {
        let quick = QuickPanelController()
        #expect(quick.settingsKey == nil)
        #expect(GlobalHotKey.canRegister(commandComma))

        quick.visibilityChanged(true)
        #expect(quick.settingsKey != nil)
        #expect(!GlobalHotKey.canRegister(commandComma))
        // Showing it again, on another tool, keeps the one registration.
        quick.visibilityChanged(true)
        #expect(!GlobalHotKey.canRegister(commandComma))

        quick.visibilityChanged(false)
        #expect(quick.settingsKey == nil)
        #expect(GlobalHotKey.canRegister(commandComma))
        quick.visibilityChanged(false)
        #expect(GlobalHotKey.canRegister(commandComma))
    }

    @Test func aScreenshotLeavesCommandCommaAlone() {
        let quick = QuickPanelController()
        quick.opensSettingsWithCommandComma = false
        quick.visibilityChanged(true)
        #expect(quick.settingsKey == nil)
        #expect(GlobalHotKey.canRegister(commandComma))
        quick.visibilityChanged(false)
    }
}
