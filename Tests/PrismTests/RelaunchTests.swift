import Foundation
import PrismKit
import Testing
@testable import Prism

struct RelaunchTests {
    private let app = "/Applications/Prism.app"

    @Test func withoutAHoldTheRelaunchOnlyWaitsAndOpens() throws {
        let command = UpdateInstaller.relaunchCommand(pid: 4242, appPath: app, hold: RelaunchHold())
        #expect(command.arguments == ["4242", app])
        #expect(command.script.contains("/usr/bin/open \"$2\""))
        #expect(!command.script.contains("caffeinate"))
        #expect(!command.script.contains(UpdateInstaller.readySignal))
        #expect(!command.script.contains("sleep \(UpdateInstaller.handoverTime)"))
        #expect(try Self.parses(command.script))
    }

    @Test func aHoldIsTakenOverBeforeThisProcessQuitsAndKeptAfterOpening() throws {
        let hold = RelaunchHold(keepsSystemAwake: true, keepsDisplayAwake: true, heldFiles: ["/var/tmp/flag"])
        let command = UpdateInstaller.relaunchCommand(pid: 4242, appPath: app, hold: hold)
        let script = command.script
        #expect(command.arguments == ["4242", app, "/var/tmp/flag"])
        #expect(script.contains("exec 3< \"$3\""))
        #expect(script.contains("/usr/bin/caffeinate -i -d -w $$"))
        #expect(script.contains(UpdateInstaller.readySignal))

        let order = [
            "exec 3<", "caffeinate -i -d", "echo \(UpdateInstaller.readySignal)", "kill -0", "/usr/bin/open",
            "sleep \(UpdateInstaller.handoverTime)",
        ].map { script.range(of: $0)?.lowerBound }
        #expect(order.allSatisfy { $0 != nil })
        #expect(order.compactMap { $0 } == order.compactMap { $0 }.sorted())
        #expect(try Self.parses(script))
    }

    @Test func onlyTheAssertionsAskedForAreHeld() {
        let systemOnly = UpdateInstaller.relaunchCommand(pid: 1, appPath: app, hold: RelaunchHold(keepsSystemAwake: true)).script
        #expect(systemOnly.contains("caffeinate -i -w"))
        #expect(!systemOnly.contains(" -d "))
        let files = UpdateInstaller.relaunchCommand(pid: 1, appPath: app, hold: RelaunchHold(heldFiles: ["/a", "/b"])).script
        #expect(!files.contains("caffeinate"))
        #expect(files.contains("exec 3< \"$3\""))
        #expect(files.contains("exec 4< \"$4\""))
        #expect(files.contains(UpdateInstaller.readySignal))
    }

    @Test func holdsMerge() {
        let merged = RelaunchHold.merged([
            RelaunchHold(keepsSystemAwake: true, heldFiles: ["/a"]),
            RelaunchHold(keepsDisplayAwake: true, heldFiles: ["/a", "/b"]),
        ])
        #expect(merged == RelaunchHold(keepsSystemAwake: true, keepsDisplayAwake: true, heldFiles: ["/a", "/b"]))
        #expect(RelaunchHold.merged([]).isEmpty)
        #expect(!merged.isEmpty)
    }

    /// `sh -n` reads the script without running any of it.
    private static func parses(_ script: String) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-n", "-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
