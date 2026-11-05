import AppKit
import LumosTool
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

        GlobalHotKey.registerToggle { [weak toolbox] in
            toolbox?.toggleHub()
        }

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
        ]
    }
}
