import AppKit
import Foundation
import Observation

/// The lid keeps a Mac asleep no matter what power assertions it holds. Only `pmset disablesleep 1` gets around
/// that, and pmset needs root.
///
/// So the first time lid sleep is turned off, one administrator prompt installs a tiny root LaunchDaemon that owns
/// the setting. Afterwards the app only has to create or delete a flag file, which needs no privileges at all.
/// The daemon also reverts the setting when the app is gone, so a crash cannot leave a Mac awake for good.
@MainActor
@Observable
final class LidControl {
    enum Status: Equatable {
        case unknown
        case disabled
        case enabled
    }

    private(set) var status = Status.unknown
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    /// Whether the daemon this build carries is installed, so the next change needs no password.
    private(set) var isHelperInstalled = false
    private(set) var enabledByApp = false

    var isSystemSleepDisabled: Bool { status == .enabled }

    /// Where this instance keeps its flag: the helper's in the app, a scratch file in tests.
    let flagPath: String
    /// Whether this process holds the flag open, which is what keeps the lid setting on.
    var holdsFlag: Bool { flag != nil }

    @ObservationIgnored private let runner: CommandRunning
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private var flag: FileHandle?
    private static let enabledByAppKey = "tools.lumos.lidSleepDisabledByApp"

    static let helperLabel = "io.github.zchan0.prism.LumosLid"
    static let daemonPath = "/Library/LaunchDaemons/\(helperLabel).plist"
    static let scriptPath = "/Library/PrivilegedHelperTools/\(helperLabel).sh"
    static let flagDirectory = "/var/tmp/\(helperLabel)"
    static let flagPath = flagDirectory + "/session"

    init(
        runner: CommandRunning = CommandRunner(),
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        flagPath: String = LidControl.flagPath
    ) {
        self.runner = runner
        self.defaults = defaults
        self.fileManager = fileManager
        self.flagPath = flagPath
        enabledByApp = defaults.bool(forKey: Self.enabledByAppKey)
    }

    private var flagDirectory: String { (flagPath as NSString).deletingLastPathComponent }

    func refresh() async {
        guard !isBusy else { return }
        isHelperInstalled = isHelperCurrent
        let result = await runner.run("/usr/bin/pmset", ["-g"])
        guard result.status == 0 else { return }
        status = Self.parseSleepDisabled(result.output) ? .enabled : .disabled
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        if enabled {
            // The app runs as the person, so it makes the folder; one made by the root installer would not let it
            // create the flag.
            guard (try? fileManager.createDirectory(atPath: flagDirectory, withIntermediateDirectories: true)) != nil else {
                errorMessage = LumosStrings.lidHelperUnavailable
                return false
            }
            if !isHelperCurrent {
                guard await installHelper() else { return false }
            }
        }

        let ok = enabled ? createFlag() : removeFlag()
        guard ok else {
            errorMessage = LumosStrings.lidHelperUnavailable
            return false
        }

        guard await waitForStatus(enabled ? .enabled : .disabled) else {
            errorMessage = LumosStrings.lidChangeTimedOut
            await refreshAfterFailure()
            return false
        }

        status = enabled ? .enabled : .disabled
        enabledByApp = enabled
        defaults.set(enabled, forKey: Self.enabledByAppKey)
        return true
    }

    /// Quitting only has to delete the flag, which needs no privileges; the daemon sees the change and puts the
    /// normal sleep setting back. Doing it synchronously keeps the work from being cancelled by termination.
    @discardableResult
    func repairSynchronously() -> Bool {
        guard fileManager.fileExists(atPath: flagPath) else { return true }
        let removed = removeFlag()
        enabledByApp = false
        defaults.set(false, forKey: Self.enabledByAppKey)
        return removed
    }

    /// Called on quit: the flag goes away so the daemon puts the normal sleep setting back.
    func repairIfNeeded() async {
        guard fileManager.fileExists(atPath: flagPath) else { return }
        _ = removeFlag()
        _ = await waitForStatus(.disabled)
        enabledByApp = false
        defaults.set(false, forKey: Self.enabledByAppKey)
    }

    /// After a relaunch for an update: holds the flag the old process left open for this one, so the lid setting
    /// carries on. False when there is no flag to hold.
    func resumeHoldingFlag() -> Bool {
        guard fileManager.fileExists(atPath: flagPath) else { return false }
        flag = Self.holdFile(at: flagPath)
        guard flag != nil else { return false }
        enabledByApp = true
        defaults.set(true, forKey: Self.enabledByAppKey)
        return true
    }

    /// The setting lives outside the app, so the panel follows pmset rather than its own memory.
    func adoptSystemState() {
        if status == .disabled, enabledByApp {
            enabledByApp = false
            defaults.set(false, forKey: Self.enabledByAppKey)
        }
    }

    static func parseSleepDisabled(_ output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, parts[0] == "SleepDisabled" else { continue }
            return parts[1] == "1"
        }
        return false
    }

    /// Exposed so the installer can be exercised without an administrator prompt in tests.
    static var installerScript: String { installScript(helperScript: helperScript, daemon: daemonPlist) }

    private func createFlag() -> Bool {
        flag = Self.holdFile(at: flagPath)
        return flag != nil
    }

    private func removeFlag() -> Bool {
        flag = nil
        guard fileManager.fileExists(atPath: flagPath) else { return true }
        do {
            try fileManager.removeItem(atPath: flagPath)
            return true
        } catch {
            return false
        }
    }

    /// Creates the file and keeps it open in one step. The kernel closes it when the app exits for any reason, crash
    /// included, which is how the daemon tells that the app is gone. A separate create and open would leave a gap in
    /// which the daemon, woken by the new file, finds nobody holding it and waits a minute before looking again.
    static func holdFile(at path: String) -> FileHandle? {
        let descriptor = open(path, O_WRONLY | O_CREAT | O_CLOEXEC, 0o644)
        return descriptor >= 0 ? FileHandle(fileDescriptor: descriptor, closeOnDealloc: true) : nil
    }

    private var isHelperCurrent: Bool {
        Self.matches(installed: installedText(Self.scriptPath), expected: Self.helperScript)
            && Self.matches(installed: installedText(Self.daemonPath), expected: Self.daemonPlist)
    }

    private func installedText(_ path: String) -> String? {
        fileManager.contents(atPath: path).map { String(decoding: $0, as: UTF8.self) }
    }

    /// A helper from another build is replaced, so a change to it reaches Macs that installed an earlier one.
    static func matches(installed: String?, expected: String) -> Bool {
        installed?.trimmingCharacters(in: .whitespacesAndNewlines) == expected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The daemon reacts in well under a second; the wait keeps the switch honest about what pmset reports.
    private func waitForStatus(_ expected: Status, attempts: Int = 20) async -> Bool {
        for _ in 0..<attempts {
            let result = await runner.run("/usr/bin/pmset", ["-g"])
            if result.status == 0, (Self.parseSleepDisabled(result.output) ? Status.enabled : .disabled) == expected {
                return true
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return false
    }

    private func refreshAfterFailure() async {
        let result = await runner.run("/usr/bin/pmset", ["-g"])
        if result.status == 0 {
            status = Self.parseSleepDisabled(result.output) ? .enabled : .disabled
        }
    }

    /// One administrator prompt installs the daemon; from then on the switch is instant and password-free.
    private func installHelper() async -> Bool {
        let encoded = Data(Self.installerScript.utf8).base64EncodedString()
        let appleScript = "do shell script \"/bin/echo \(encoded) | /usr/bin/base64 -D | /bin/zsh\" with administrator privileges"
        let result = await runner.run("/usr/bin/osascript", ["-e", appleScript])
        guard result.status == 0 else {
            let detail = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = detail.isEmpty ? LumosStrings.adminPasswordRequired : LumosStrings.lidCommandFailed(detail)
            return false
        }
        isHelperInstalled = isHelperCurrent
        if !isHelperInstalled {
            errorMessage = LumosStrings.lidHelperUnavailable
        }
        return isHelperInstalled
    }

    /// Runs as root, flips pmset to match the flag file, and puts sleep back when the app is not running.
    static let helperScript = """
    #!/bin/zsh
    # Runs as root from the LaunchDaemon. Sets lid sleep to match the flag, and never leaves it off after the
    # app is gone, so a crash cannot keep a Mac awake for good.
    flag=\(flagPath)
    want=0
    # The app holds the flag open while it wants lid sleep off, and the kernel closes it however the app exits.
    if [[ -e "$flag" ]] && /usr/sbin/lsof -t -- "$flag" > /dev/null 2>&1; then
      want=1
    fi
    # pmset leaves the line out when the setting is off, so an empty answer means 0.
    have=$(/usr/bin/pmset -g | /usr/bin/awk '/SleepDisabled/ { print $2 }')
    have=${have:-0}
    # pmset writes a system setting, so it is only called when the value actually has to change.
    if [[ "$have" != "$want" ]]; then
      /usr/bin/pmset -a disablesleep $want
    fi
    """

    static var daemonPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(helperLabel)</string>
            <key>ProgramArguments</key><array><string>\(scriptPath)</string></array>
            <key>RunAtLoad</key><true/>
            <key>StartInterval</key><integer>60</integer>
            <key>WatchPaths</key><array><string>\(flagDirectory)</string></array>
        </dict>
        </plist>
        """
    }

    /// One shell script, because `do shell script X with administrator privileges` runs a single command.
    static func installScript(helperScript: String, daemon: String) -> String {
        """
        set -e
        mkdir -p /Library/PrivilegedHelperTools
        cat > \(scriptPath) <<'HELPER_SCRIPT'
        \(helperScript)
        HELPER_SCRIPT
        chmod 755 \(scriptPath)
        chown root:wheel \(scriptPath)
        cat > \(daemonPath) <<'HELPER_PLIST'
        \(daemon)
        HELPER_PLIST
        chown root:wheel \(daemonPath)
        chmod 644 \(daemonPath)
        /bin/launchctl bootout system/\(helperLabel) > /dev/null 2>&1 || true
        /bin/launchctl bootstrap system \(daemonPath)
        /bin/launchctl kickstart -k system/\(helperLabel) > /dev/null 2>&1 || true
        """
    }
}

/// The panel closes when it loses focus, so the lid confirmation is an app-modal alert rather than a sheet.
@MainActor
enum LidPrompter {
    static func presentLidPrompt(model: AppModel) {
        let alert = NSAlert()
        alert.messageText = LumosStrings.lidClosed
        alert.informativeText = LumosStrings.lidClosedNote
        alert.addButton(withTitle: LumosStrings.continueButton)
        alert.addButton(withTitle: LumosStrings.cancel)
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await model.setKeepsAwakeWithLidClosed(true) }
    }
}

struct CommandResult: Equatable, Sendable {
    var status: Int32
    var output: String
    var error: String
}

@MainActor
protocol CommandRunning: AnyObject {
    func run(_ executable: String, _ arguments: [String]) async -> CommandResult
}

@MainActor
final class CommandRunner: CommandRunning {
    func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            let errors = Pipe()
            process.standardOutput = pipe
            process.standardError = errors
            process.terminationHandler = { finished in
                let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let error = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: CommandResult(status: finished.terminationStatus, output: output, error: error))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: CommandResult(status: -1, output: "", error: error.localizedDescription))
            }
        }
    }
}
