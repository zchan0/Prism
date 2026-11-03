import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var controller: StatusItemController?
    private var ticker: Ticker?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let appearance = ProcessInfo.processInfo.environment["LUMOS_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        if let path = ProcessInfo.processInfo.environment["LUMOS_SNAPSHOT"], !path.isEmpty {
            let fixture = ProcessInfo.processInfo.environment["LUMOS_FIXTURE"] == "1"
            Task {
                let asleep = ProcessInfo.processInfo.environment["LUMOS_PANEL_STATE"] == "asleep"
                let succeeded = await DebugSnapshot.writePanel(to: path, fixture: fixture, asleep: asleep)
                exit(succeeded ? 0 : 1)
            }
            return
        }
        if let path = ProcessInfo.processInfo.environment["LUMOS_PET_SNAPSHOT"], !path.isEmpty {
            Task {
                let awake = ProcessInfo.processInfo.environment["LUMOS_PET_STATE"] != "asleep"
                let succeeded = await DebugSnapshot.writePet(to: path, awake: awake)
                exit(succeeded ? 0 : 1)
            }
            return
        }
        if let path = ProcessInfo.processInfo.environment["LUMOS_STATUS_SNAPSHOT"], !path.isEmpty {
            exit(DebugSnapshot.writeStatus(to: path) ? 0 : 1)
        }
        if let path = ProcessInfo.processInfo.environment["LUMOS_SETTINGS_SNAPSHOT"], !path.isEmpty {
            let tab = ProcessInfo.processInfo.environment["LUMOS_SETTINGS_TAB"].flatMap(SettingsWindowController.Tab.init(rawValue:)) ?? .general
            let settings = SettingsWindowController.shared(for: model)
            Task {
                let succeeded = await DebugSnapshot.writeSettings(to: path, settings: settings, tab: tab)
                exit(succeeded ? 0 : 1)
            }
            return
        }
        #endif

        let controller = StatusItemController(model: model)
        self.controller = controller
        model.launch()

        #if DEBUG
        if ProcessInfo.processInfo.environment["LUMOS_OPEN_PANEL"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                controller.showPanelForDebug()
                try? await Task.sleep(for: .seconds(1.2))
                if let path = ProcessInfo.processInfo.environment["LUMOS_PANEL_CAPTURE"] {
                    let ok = await DebugSnapshot.capture(window: controller.panelWindowForDebug, to: path)
                    exit(ok ? 0 : 1)
                }
            }
        }
        #endif

        let ticker = Ticker()
        ticker.start(every: 1) { [weak controller] in controller?.tick() }
        self.ticker = ticker

        GlobalHotKey.registerToggle { [weak model] in model?.toggle() }

        #if DEBUG
        if let seconds = ProcessInfo.processInfo.environment["LUMOS_AUTO_START"].flatMap(Double.init) {
            model.start(length: SessionLength(rawValue: Int(seconds / 60)) ?? .forever)
        }
        if let seconds = ProcessInfo.processInfo.environment["LUMOS_TIMER_SECONDS"].flatMap(Double.init) {
            model.start(length: .forever)
            model.engine.startForDebug(seconds: seconds, keepsDisplayAwake: model.preferences.keepsDisplayAwake)
        }
        if ProcessInfo.processInfo.environment["LUMOS_PET_CLICK"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                controller.clickPetForDebug()
                try? await Task.sleep(for: .seconds(1.2))
                let ok = await DebugSnapshot.capture(window: controller.panelWindowForDebug, to: ProcessInfo.processInfo.environment["LUMOS_PET_CLICK"] == "1" && ProcessInfo.processInfo.environment["LUMOS_PANEL_CAPTURE"] != nil ? ProcessInfo.processInfo.environment["LUMOS_PANEL_CAPTURE"]! : "/tmp/pet-panel.png")
                exit(ok ? 0 : 1)
            }
        }
        if ProcessInfo.processInfo.environment["LUMOS_DUMP"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(2))
                print(DebugSnapshot.dump(model: model))
                exit(0)
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        ticker?.stop()
        model.stop()
        // Deleting the flag is all it takes; the root helper sees it and restores normal sleep.
        model.repairOnQuit()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
