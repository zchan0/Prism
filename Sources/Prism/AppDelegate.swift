import AppKit
import LumosTool
import PensieveTool
import PortkeyTool
import VitalsTool
import PrismKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var toolbox: ToolboxApp?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let appearance = ProcessInfo.processInfo.environment["PRISM_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        #endif

        let registrations = Self.registrations()
        let toolbox = ToolboxApp(
            registrations: registrations,
            shell: ShellSettings(registrations: registrations)
        )
        self.toolbox = toolbox
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        // A run with a debug hook never opens the window on its own: it would cover what a capture is about to take.
        let welcomes = !environment.keys.contains { $0.hasPrefix("PRISM_") }
        let lumos = registrations.first(where: { $0.id == LumosTool.id })?.tool as? LumosTool
        let pensieve = registrations.first(where: { $0.id == PensieveTool.id })?.tool as? PensieveTool
        let portkey = registrations.first(where: { $0.id == PortkeyTool.id })?.tool as? PortkeyTool
        // Before launch, which starts the tools: Pensieve would otherwise watch the clipboard and read its history,
        // and Portkey would set up the person's shortcuts. A packaged debug build reads the installed Prism's settings.
        if environment["PRISM_CAPTURE"] != nil || environment["PRISM_STATUS_CAPTURE"] != nil {
            lumos?.leaveLidAloneForDebug()
            if let pensieve {
                PensieveDebug.showSamples(pensieve)
            }
            if let portkey {
                PortkeyDebug.showSamples(portkey)
            }
        }
        #else
        let welcomes = true
        #endif
        toolbox.launch(welcomes: welcomes)

        #if DEBUG
        if environment["PRISM_START_LUMOS"] == "1", let lumos {
            lumos.startForDebug()
        }
        if let directory = environment["PRISM_CAPTURE"] {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                var ok = await toolbox.capture(to: directory)
                if let lumos {
                    lumos.showNotesForDebug(true)
                    ok = await toolbox.capturePanel(of: LumosTool.id, to: "\(directory)/popover-lumos-note.png") && ok
                    toolbox.hideQuickPanel()
                    ok = await toolbox.capturePage(of: LumosTool.id, to: "\(directory)/window-lumos-note.png") && ok
                    lumos.showNotesForDebug(false)
                }
                if let pensieve {
                    let window = PensieveDebug.historyWindow(pensieve)
                    window.center()
                    ok = await DebugCapture.window(window, to: "\(directory)/pensieve-window.png") && ok
                    let picked = PensieveDebug.filterImagesThroughMenu(pensieve) {
                        _ = DebugCapture.screen(around: window.frame, to: "\(directory)/pensieve-filter-menu.png")
                    }
                    print("filter menu: \(picked ? "opened, Images picked" : "did not open or pick")")
                    ok = await DebugCapture.window(window, to: "\(directory)/pensieve-window-images.png") && picked && ok
                    if let preview = PensieveDebug.previewWindow(pensieve) {
                        ok = await DebugCapture.window(preview, to: "\(directory)/pensieve-preview.png") && ok
                    } else {
                        print("preview: not shown")
                        ok = false
                    }
                }
                exit(ok ? 0 : 1)
            }
        }
        if let path = environment["PRISM_STATUS_CAPTURE"] {
            exit(DebugCapture.statusIcons(to: path) ? 0 : 1)
        }
        if environment["PRISM_DUMP"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(2))
                print(registrations.map { "\($0.id): \($0.tool.summary)" }.joined(separator: "\n"))
                exit(0)
            }
        }
        if let bundleID = environment["PRISM_PORTKEY_SWITCH"] {
            Task {
                try? await Task.sleep(for: .seconds(3))
                PortkeyDebug.switchTo(bundleID: bundleID)
            }
        }
        #endif
    }

    /// Opening Prism while it runs, from Finder, Spotlight or Launchpad, opens the Prism window: with no Dock icon,
    /// that is the only thing opening it again can mean.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toolbox?.openWindow(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        toolbox?.terminate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// The one place that lists the tools. Adding one means adding a module and a line here.
    private static func registrations() -> [ToolRegistration] {
        [
            ToolRegistration(LumosTool(), defaultPlacement: .ownIcon),
            ToolRegistration(VitalsTool(), defaultPlacement: .ownIcon),
            ToolRegistration(PortkeyTool(), defaultPlacement: .hubOnly),
            ToolRegistration(PensieveTool(), defaultPlacement: .hubOnly),
        ]
    }
}
