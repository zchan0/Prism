import AppKit
import AwakeTool
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

        // Before any tool reads a setting, so the first launch after the rename looks like an upgrade.
        SettingsMigration.runIfNeeded()
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
        if ProcessInfo.processInfo.environment["PRISM_START_AWAKE"] == "1",
           let awake = registrations.first(where: { $0.id.rawValue == "awake" })?.tool as? AwakeTool {
            awake.startForDebug()
        }
        if let path = ProcessInfo.processInfo.environment["PRISM_SETTINGS_CAPTURE"] {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                let ok = await DebugCapture.window(toolbox.settingsWindow(), to: path)
                exit(ok ? 0 : 1)
            }
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
            ToolRegistration(AwakeTool(), defaultPlacement: .ownIcon),
            ToolRegistration(VitalsTool(), defaultPlacement: .ownIcon),
        ]
    }
}
