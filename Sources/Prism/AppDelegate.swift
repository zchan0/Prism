import AppKit
import LumosTool
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
        toolbox.launch()

        #if DEBUG
        if ProcessInfo.processInfo.environment["PRISM_START_LUMOS"] == "1",
           let lumos = registrations.first(where: { $0.id.rawValue == "lumos" })?.tool as? LumosTool {
            lumos.startForDebug()
        }
        if let directory = ProcessInfo.processInfo.environment["PRISM_CAPTURE"] {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                let ok = await toolbox.capturePanels(to: directory)
                exit(ok ? 0 : 1)
            }
        }
        if let path = ProcessInfo.processInfo.environment["PRISM_STATUS_CAPTURE"] {
            exit(DebugCapture.statusIcons(to: path) ? 0 : 1)
        }
        if ProcessInfo.processInfo.environment["PRISM_DUMP"] == "1" {
            Task {
                try? await Task.sleep(for: .seconds(2))
                print(registrations.map { "\($0.id): \($0.tool.summary)" }.joined(separator: "\n"))
                exit(0)
            }
        }
        if let bundleID = ProcessInfo.processInfo.environment["PRISM_PORTKEY_SWITCH"] {
            Task {
                try? await Task.sleep(for: .seconds(3))
                PortkeyDebug.switchTo(bundleID: bundleID)
            }
        }
        if let name = ProcessInfo.processInfo.environment["PRISM_SHOW_PANEL"] {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                toolbox.showPanelForDebug(name)
            }
        }
        if ProcessInfo.processInfo.environment["PRISM_PORTKEY_WINDOW"] == "1",
           let portkey = registrations.first(where: { $0.id == PortkeyTool.id })?.tool as? PortkeyTool {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                PortkeyDebug.openWindow(portkey)
            }
        }
        #endif
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
        ]
    }
}
