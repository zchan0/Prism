import AppKit
import Carbon.HIToolbox
import Foundation
import PrismKit
import Testing
@testable import PortkeyTool

struct AppSwitcherDecisionTests {
    private let xcode = URL(fileURLWithPath: "/Applications/Xcode.app", isDirectory: true)
    private let xcodeBeta = URL(fileURLWithPath: "/Applications/Xcode-beta.app", isDirectory: true)

    private func decide(
        savedURL: URL? = nil,
        savedURLExists: Bool = false,
        running: [AppSwitcher.RunningApp] = [],
        frontmostPID: pid_t? = nil,
        installedURL: URL? = nil
    ) -> AppSwitcher.Decision {
        AppSwitcher.decide(
            savedURL: savedURL,
            savedURLExists: savedURLExists,
            running: running,
            frontmostPID: frontmostPID,
            installedURL: installedURL
        )
    }

    @Test func hidesTheAppWhenItIsAlreadyInFront() {
        let decision = decide(running: [.init(pid: 42, bundleURL: xcode)], frontmostPID: 42, installedURL: xcode)
        #expect(decision == .hide(pid: 42))
    }

    @Test func bringsARunningAppToTheFront() {
        let decision = decide(running: [.init(pid: 42, bundleURL: xcode)], frontmostPID: 7, installedURL: xcodeBeta)
        #expect(decision == .open(xcode))
    }

    @Test func opensTheSavedCopyWhenNothingRuns() {
        let decision = decide(savedURL: xcodeBeta, savedURLExists: true, frontmostPID: 7, installedURL: xcode)
        #expect(decision == .open(xcodeBeta))
    }

    @Test func fallsBackToLaunchServicesWhenTheSavedCopyIsGone() {
        let decision = decide(savedURL: xcodeBeta, savedURLExists: false, frontmostPID: 7, installedURL: xcode)
        #expect(decision == .open(xcode))
    }

    @Test func doesNothingWhenTheAppCannotBeFound() {
        #expect(decide(savedURL: xcodeBeta, savedURLExists: false, frontmostPID: 7) == .nothing)
        #expect(decide() == .nothing)
    }

    @Test func opensTheSavedCopyRatherThanHidingTheOtherOne() {
        let decision = decide(
            savedURL: xcodeBeta,
            savedURLExists: true,
            running: [.init(pid: 42, bundleURL: xcode)],
            frontmostPID: 42,
            installedURL: xcode
        )
        #expect(decision == .open(xcodeBeta))
    }

    @Test func matchesTheSavedCopyHoweverItsPathIsSpelled() {
        let decision = decide(
            savedURL: URL(fileURLWithPath: "/Applications/Tools/../Xcode-beta.app", isDirectory: false),
            savedURLExists: true,
            running: [.init(pid: 42, bundleURL: xcode), .init(pid: 43, bundleURL: xcodeBeta)],
            frontmostPID: 43,
            installedURL: xcode
        )
        #expect(decision == .hide(pid: 43))
    }
}

@MainActor
@Suite(.serialized)
struct GlobalHotKeyTests {
    private let keyCode = UInt32(kVK_F19)
    private let modifiers = UInt32(controlKey | optionKey | cmdKey | shiftKey)

    @Test func registersAnUnusedCombination() throws {
        let registration = try GlobalHotKey.register(keyCode: keyCode, modifiers: modifiers) {}.get()
        GlobalHotKey.unregister(registration)
    }

    @Test func refusesACombinationThatIsTaken() throws {
        let first = try GlobalHotKey.register(keyCode: keyCode, modifiers: modifiers) {}.get()
        defer { GlobalHotKey.unregister(first) }
        switch GlobalHotKey.register(keyCode: keyCode, modifiers: modifiers, action: {}) {
        case .success(let second):
            GlobalHotKey.unregister(second)
            Issue.record("The same combination registered twice")
        case .failure(let error):
            #expect(error.status == OSStatus(eventHotKeyExistsErr))
        }
    }

    @Test func freesTheCombinationOnUnregister() throws {
        let first = try GlobalHotKey.register(keyCode: keyCode, modifiers: modifiers) {}.get()
        GlobalHotKey.unregister(first)
        let second = try GlobalHotKey.register(keyCode: keyCode, modifiers: modifiers) {}.get()
        #expect(second != first)
        GlobalHotKey.unregister(second)
    }
}

struct ShortcutTests {
    @Test func modifiersReadInTheOrderMacOSWritesThem() {
        let all = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: all, keyName: "C").text == "⌃⌥⇧⌘C")
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(shiftKey | optionKey), keyName: "C").text == "⌥⇧C")
        #expect(Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey | controlKey), keyName: "F5").text == "⌃⌘F5")
    }

    @Test func keysAreOneForEachModifierThenTheKey() {
        let all = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let everything = Shortcut(keyCode: UInt32(kVK_F14), modifiers: all, keyName: "F14")
        #expect(everything.keys == ["⌃", "⌥", "⇧", "⌘", "F14"])
        #expect(everything.text == everything.keys.joined())
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(shiftKey | optionKey), keyName: "C").keys == ["⌥", "⇧", "C"])
        #expect(Shortcut(keyCode: UInt32(kVK_F15), modifiers: UInt32(cmdKey), keyName: "F15").keys == ["⌘", "F15"])
    }

    @Test func aRecordedKeyIsNamedWithoutItsModifiers() throws {
        // ⌥⇧1 types ⁄ on a US layout; the name must still be 1.
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.option, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "⁄",
            charactersIgnoringModifiers: "!",
            isARepeat: false,
            keyCode: UInt16(kVK_ANSI_1)
        ))
        #expect(Shortcut(event: event).text == "⌥⇧1")
    }

    @Test func keysThatTypeNothingVisibleHaveNames() {
        #expect(Shortcut.keyName(keyCode: kVK_Space, characters: " ") == "Space")
        #expect(Shortcut.keyName(keyCode: kVK_F5, characters: "\u{10}") == "F5")
        #expect(Shortcut.keyName(keyCode: kVK_LeftArrow, characters: "\u{F702}") == "←")
        #expect(Shortcut.keyName(keyCode: kVK_ANSI_C, characters: "c") == "C")
    }

    @Test func theKeyNameDoesNotMakeAnotherShortcut() {
        let option = UInt32(optionKey)
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: option, keyName: "C")
            == Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: option, keyName: "Ç"))
        #expect(Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: option, keyName: "C")
            != Shortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: option | UInt32(shiftKey), keyName: "C"))
    }
}

@MainActor
struct PortkeyToolTests {
    private let defaults = MemoryDefaults()

    private func tool() -> PortkeyTool {
        PortkeyTool(settings: ToolSettings(tool: PortkeyTool.id, defaults: defaults))
    }

    private func candidate(_ number: Int) -> AppCandidate {
        AppCandidate(bundleID: "com.example.app\(number)", path: "/Applications/App \(number).app", name: "App \(number)")
    }

    private func shortcut(_ keyCode: Int, _ modifiers: Int, _ keyName: String) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers), keyName: keyName)
    }

    // Combinations nobody uses, because a started tool registers them for real.
    private var f17: Shortcut { shortcut(kVK_F17, controlKey | optionKey | cmdKey | shiftKey, "F17") }
    private var f18: Shortcut { shortcut(kVK_F18, controlKey | optionKey | cmdKey | shiftKey, "F18") }

    @Test func aNewAppHasNoShortcut() {
        let portkey = tool()
        portkey.add(candidate(1))
        portkey.add(candidate(2))
        #expect(portkey.apps.map(\.shortcut) == [nil, nil])
    }

    @Test func theAppsAndTheirShortcutsSurviveARelaunch() throws {
        let first = tool()
        first.add(candidate(1))
        first.add(candidate(2))
        let second = try #require(first.apps.last)
        #expect(first.setShortcut(shortcut(kVK_ANSI_C, optionKey | shiftKey, "C"), for: second.id) == nil)

        let relaunched = tool()
        #expect(relaunched.apps == first.apps)
        #expect(relaunched.apps.map { $0.shortcut?.text } == [nil, "⌥⇧C"])
    }

    @Test func aShortcutAnotherAppHasIsRefused() throws {
        let portkey = tool()
        portkey.add(candidate(1))
        portkey.add(candidate(2))
        let first = try #require(portkey.apps.first)
        let second = try #require(portkey.apps.last)
        #expect(portkey.setShortcut(shortcut(kVK_ANSI_C, optionKey | shiftKey, "C"), for: first.id) == nil)
        #expect(portkey.setShortcut(shortcut(kVK_ANSI_X, optionKey | shiftKey, "X"), for: second.id) == nil)
        let before = portkey.apps

        let refusal = portkey.setShortcut(shortcut(kVK_ANSI_C, optionKey | shiftKey, "Ç"), for: second.id)
        #expect(refusal == .usedBy(try #require(portkey.apps.first)))
        #expect(portkey.apps == before)
        #expect(portkey.apps.last?.shortcut?.text == "⌥⇧X")
    }

    @Test func aShortcutNeedsCommandControlOrOption() throws {
        let portkey = tool()
        portkey.add(candidate(1))
        let app = try #require(portkey.apps.first)
        #expect(portkey.setShortcut(shortcut(kVK_ANSI_C, 0, "C"), for: app.id) == .needsModifier)
        #expect(portkey.setShortcut(shortcut(kVK_ANSI_C, shiftKey, "C"), for: app.id) == .needsModifier)
        #expect(portkey.apps.first?.shortcut == nil)
        #expect(portkey.setShortcut(shortcut(kVK_ANSI_C, controlKey, "C"), for: app.id) == nil)
    }

    @Test func aShortcutCanBeCleared() throws {
        let portkey = tool()
        portkey.add(candidate(1))
        let app = try #require(portkey.apps.first)
        portkey.setShortcut(shortcut(kVK_ANSI_C, optionKey, "C"), for: app.id)
        #expect(portkey.setShortcut(nil, for: app.id) == nil)
        #expect(tool().apps.first?.shortcut == nil)
    }

    @Test func aShortcutMacOSRefusesIsNotKept() throws {
        let taken = try GlobalHotKey.register(keyCode: f18.keyCode, modifiers: f18.modifiers) {}.get()
        defer { GlobalHotKey.unregister(taken) }
        let portkey = tool()
        portkey.add(candidate(1))
        let app = try #require(portkey.apps.first)
        portkey.start()
        defer { portkey.stop() }

        #expect(portkey.setShortcut(f18, for: app.id) == .refusedBySystem)
        #expect(portkey.apps.first?.shortcut == nil)
    }

    @Test func aSavedShortcutMacOSRefusesIsFlagged() throws {
        let taken = try GlobalHotKey.register(keyCode: f18.keyCode, modifiers: f18.modifiers) {}.get()
        defer { GlobalHotKey.unregister(taken) }
        let first = tool()
        first.add(candidate(1))
        let app = try #require(first.apps.first)
        first.setShortcut(f18, for: app.id)

        let relaunched = tool()
        relaunched.start()
        defer { relaunched.stop() }
        #expect(relaunched.failedAppIDs == [app.id])
    }

    @Test func pausedShortcutsAreFreeUntilTheyResume() throws {
        let portkey = tool()
        portkey.add(candidate(1))
        let app = try #require(portkey.apps.first)
        portkey.start()
        defer { portkey.stop() }
        #expect(portkey.setShortcut(f17, for: app.id) == nil)
        #expect(!isFree(f17))

        portkey.setShortcutsPaused(true)
        #expect(isFree(f17))
        portkey.setShortcutsPaused(false)
        #expect(!isFree(f17))
    }

    private func isFree(_ shortcut: Shortcut) -> Bool {
        guard case .success(let registration) = GlobalHotKey.register(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers,
            action: {}
        ) else { return false }
        GlobalHotKey.unregister(registration)
        return true
    }

    @Test func theSameAppCannotBeAddedTwice() {
        let portkey = tool()
        #expect(portkey.add(candidate(1)))
        #expect(!portkey.add(candidate(1)))
        #expect(portkey.apps.count == 1)
        // A second copy with the same bundle id, such as a beta, is another app.
        let copy = AppCandidate(bundleID: "com.example.app1", path: "/Applications/App 1 Beta.app", name: "App 1 Beta")
        #expect(portkey.add(copy))
        #expect(portkey.apps.count == 2)
    }

    @Test func aBrokenListReadsAsNoApps() {
        ToolSettings(tool: PortkeyTool.id, defaults: defaults).set("[{\"id\": 1", for: "apps")
        #expect(tool().apps.isEmpty)
    }

    @Test func theSymbolsAreThere() {
        // Without one, turning on Show in the menu bar would leave the tool without an icon.
        #expect(tool().statusIcons().map(\.id) == ["door"])
        for symbol in ["door.left.hand.open", "minus.circle.fill", "plus"] {
            #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)")
        }
    }
}

#if DEBUG
extension PortkeyToolTests {
    @Test func theSamplesAreAppsEveryMacHas() {
        for app in PortkeyDebug.samples {
            #expect(FileManager.default.fileExists(atPath: app.path), "\(app.path)")
            #expect(Bundle(path: app.path)?.bundleIdentifier == app.bundleID, "\(app.path)")
        }
        #expect(PortkeyDebug.samples.map { $0.shortcut?.text } == ["⌥⇧S", "⌥⇧M", "⌃⌘N", nil])
    }

    @Test func samplesAreNeitherSavedNorSetUp() throws {
        let portkey = tool()
        portkey.add(candidate(1))
        let app = try #require(portkey.apps.first)
        portkey.start()
        defer { portkey.stop() }
        #expect(portkey.setShortcut(f17, for: app.id) == nil)
        #expect(!isFree(f17))
        let stored = ToolSettings(tool: PortkeyTool.id, defaults: defaults)
        let saved = stored.string("apps", default: "")

        PortkeyDebug.showSamples(portkey)
        #expect(portkey.apps == PortkeyDebug.samples)
        #expect(portkey.registrations.isEmpty)
        #expect(isFree(f17))

        // Nothing the window or the hub can do afterwards sets up a shortcut or saves the list.
        let terminal = try #require(portkey.apps.last)
        #expect(portkey.setShortcut(f18, for: terminal.id) == nil)
        portkey.setShortcutsPaused(true)
        portkey.setShortcutsPaused(false)
        portkey.stop()
        portkey.start()
        #expect(portkey.registrations.isEmpty)
        #expect(isFree(f17))
        #expect(isFree(f18))
        portkey.remove(terminal.id)
        #expect(portkey.add(candidate(2)))
        #expect(stored.string("apps", default: "") == saved)
    }
}
#endif

struct DockAppsTests {
    private func tile(_ bundleID: String?, _ url: String?, label: String? = nil) -> [String: Any] {
        var tile: [String: Any] = [:]
        if let bundleID { tile["bundle-identifier"] = bundleID }
        if let url { tile["file-data"] = ["_CFURLString": url, "_CFURLStringType": 15] }
        if let label { tile["file-label"] = label }
        return ["tile-data": tile, "tile-type": "file-tile"]
    }

    @Test func readsTheAppsInTheDockThatAreStillThere() {
        let persistentApps: [Any] = [
            tile("com.google.Chrome", "file:///Applications/Google%20Chrome.app/", label: "Google Chrome"),
            tile("com.example.gone", "file:///Applications/Gone.app/", label: "Gone"),
            tile(nil, "file:///Applications/NoID.app/", label: "No ID"),
            tile("com.example.nourl", nil, label: "No URL"),
            tile("com.electron.lark", "file:///Applications/Lark.app/"),
            ["tile-type": "spacer-tile"],
        ]
        let existing: Set<String> = ["/Applications/Google Chrome.app", "/Applications/Lark.app", "/Applications/NoID.app"]
        let apps = AppCandidate.dockApps(persistentApps: persistentApps) { existing.contains($0) }
        #expect(apps == [
            AppCandidate(bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app", name: "Google Chrome"),
            AppCandidate(bundleID: "com.electron.lark", path: "/Applications/Lark.app", name: "Lark"),
        ])
    }

    @Test func anEmptyDockHasNoApps() {
        #expect(AppCandidate.dockApps(persistentApps: []) { _ in true }.isEmpty)
    }
}
