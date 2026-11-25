import CryptoKit
import Foundation
import PrismKit
import Security

/// Everything an update does to files and processes, so the updater can be tested without either.
protocol UpdateInstalling: Sendable {
    /// Whether this copy of Prism can replace itself: it can write its bundle and the folder it is in, and macOS has
    /// not moved it to a randomized read-only path, as it does with an app opened from where it was downloaded.
    var canInstall: Bool { get }
    /// Downloads the release, checks it, unpacks it, and returns the Prism.app that is ready to take this one's
    /// place. `progress` gets the bytes received so far. Cancelling stops the download and deletes what it left.
    func download(_ release: Release, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL
    /// Puts the downloaded app in place of this one.
    func install(_ stagedApp: URL) async throws
    /// Opens Prism again once this process has quit, holding what `hold` names from before this process quits until
    /// the new one has had time to take over. Returns once the hold is in place; the caller quits right after.
    func relaunch(holding hold: RelaunchHold) async throws
    /// Deletes everything downloads have left behind.
    func cleanUp()
}

struct UpdateInstaller: UpdateInstalling {
    static let defaultWorkDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("io.github.zchan0.prism", isDirectory: true)
        .appendingPathComponent("Update", isDirectory: true)

    let bundleURL: URL
    /// What the downloaded app's bundle identifier has to be.
    let bundleID: String?
    let workDirectory: URL

    init(
        bundleURL: URL = Bundle.main.bundleURL,
        bundleID: String? = Bundle.main.bundleIdentifier,
        workDirectory: URL = UpdateInstaller.defaultWorkDirectory
    ) {
        self.bundleURL = bundleURL
        self.bundleID = bundleID
        self.workDirectory = workDirectory
    }

    var canInstall: Bool {
        let fileManager = FileManager.default
        return !bundleURL.path.contains("/AppTranslocation/")
            && fileManager.isWritableFile(atPath: bundleURL.path)
            && fileManager.isWritableFile(atPath: bundleURL.deletingLastPathComponent().path)
    }

    @concurrent
    func download(_ release: Release, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL {
        cleanUp()
        // Its own folder, so a cancelled download that cleans up late cannot delete the next one's files.
        let folder = workDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                throw UpdateError(.download, "could not create \(folder.path): \(error)")
            }
            let archive = folder.appendingPathComponent("Prism-\(release.version).zip")
            try await Self.fetch(release.archiveURL, to: archive, progress: progress)
            try Task.checkCancellation()
            try Self.verifyChecksum(of: archive, expected: release.sha256)
            let unpacked = folder.appendingPathComponent("Unpacked", isDirectory: true)
            try await Self.unpack(archive, into: unpacked)
            try Task.checkCancellation()
            let app = unpacked.appendingPathComponent("Prism.app", isDirectory: true)
            try verify(app, as: release)
            return app
        } catch {
            try? FileManager.default.removeItem(at: folder)
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
    }

    @concurrent
    func install(_ stagedApp: URL) async throws {
        do {
            _ = try FileManager.default.replaceItemAt(bundleURL, withItemAt: stagedApp)
        } catch {
            throw UpdateError(.install, "could not replace \(bundleURL.path): \(error)")
        }
    }

    @concurrent
    func relaunch(holding hold: RelaunchHold) async throws {
        let command = Self.relaunchCommand(
            pid: ProcessInfo.processInfo.processIdentifier,
            appPath: bundleURL.path,
            hold: hold
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command.script, "sh"] + command.arguments
        // open passes its environment to the app it opens, and Prism passes its own to every app Portkey opens, so
        // the new Prism starts with only what a login gives, like scripts/install.sh does.
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        for key in ["HOME", "USER", "LOGNAME", "SHELL"] {
            environment[key] = inherited[key]
        }
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = hold.isEmpty ? FileHandle.nullDevice : output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UpdateError(.install, "could not start the relaunch: \(error)")
        }
        guard !hold.isEmpty else { return }
        let ready = await LineWaiter(line: Self.readySignal).wait(on: output.fileHandleForReading, timeout: Self.readyTimeout)
        guard ready else {
            // Whatever it held goes with it; this process still holds its own.
            process.terminate()
            throw UpdateError(.install, "the relaunch did not take over in \(Self.readyTimeout) s")
        }
    }

    static let readySignal = "prism-relaunch-ready"
    static let readyTimeout: TimeInterval = 2
    /// How long the relaunch keeps holding after opening Prism, for the new process to take over.
    static let handoverTime = 10

    /// The shell script that relaunches Prism, and the arguments after it: wait for this process to quit, then open the
    /// app. With a hold, the script first opens the held files and starts caffeinate, prints `readySignal` once both
    /// are in place, and stays a while after opening the app; caffeinate quits with it.
    static func relaunchCommand(pid: Int32, appPath: String, hold: RelaunchHold) -> (script: String, arguments: [String]) {
        let arguments = [String(pid), appPath] + hold.heldFiles
        let waitAndOpen = """
        while /bin/kill -0 "$1" 2> /dev/null; do /bin/sleep 0.2; done
        /usr/bin/open "$2"
        """
        guard !hold.isEmpty else {
            return (waitAndOpen, arguments)
        }
        var lines: [String] = []
        for index in hold.heldFiles.indices {
            // The parameter and the descriptor share a number, from 3 on: $1 and $2 are the pid and the app.
            let number = index + 3
            lines.append("[ -e \"$\(number)\" ] && exec \(number)< \"$\(number)\"")
        }
        if hold.keepsSystemAwake || hold.keepsDisplayAwake {
            let flags = (hold.keepsSystemAwake ? ["-i"] : []) + (hold.keepsDisplayAwake ? ["-d"] : [])
            // -w ties caffeinate to this shell, so it never outlives the relaunch. Ready only once its assertion is
            // listed, so this process never quits before caffeinate holds the Mac awake.
            lines.append("""
            /usr/bin/caffeinate \(flags.joined(separator: " ")) -w $$ &
            caffeinate=$!
            tries=0
            until /usr/bin/pmset -g assertions | /usr/bin/grep -qF "pid $caffeinate(caffeinate)"; do
              tries=$((tries + 1))
              [ $tries -gt 30 ] && exit 1
              /bin/sleep 0.05
            done
            """)
        }
        lines.append("echo \(readySignal)")
        // Nobody reads the pipe once Prism has quit, and writing to it then would kill the script.
        lines.append("exec 1> /dev/null")
        lines.append(waitAndOpen)
        lines.append("/bin/sleep \(handoverTime)")
        return (lines.joined(separator: "\n"), arguments)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    private static func fetch(_ url: URL, to destination: URL, progress: @escaping @Sendable (Int64) -> Void) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        // A minute without data fails the download, however long the whole of it takes.
        configuration.timeoutIntervalForRequest = 60
        let delegate = DownloadDelegate(destination: destination, progress: progress)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: url)
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    delegate.wait(with: continuation)
                    task.resume()
                }
            } onCancel: {
                task.cancel()
            }
        } catch let error as UpdateError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw UpdateError(.download, error.localizedDescription)
        }
    }

    private static func verifyChecksum(of archive: URL, expected: String) throws {
        let data: Data
        do {
            data = try Data(contentsOf: archive, options: .mappedIfSafe)
        } catch {
            throw UpdateError(.download, "could not read the download: \(error)")
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw UpdateError(.verification, "SHA-256 is \(actual), the release says \(expected)")
        }
    }

    private static func unpack(_ archive: URL, into directory: URL) async throws {
        let status: Int32 = await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archive.path, directory.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
        guard status == 0 else {
            throw UpdateError(.verification, "ditto could not unpack the archive (\(status))")
        }
    }

    private func verify(_ app: URL, as release: Release) throws {
        let plist = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw UpdateError(.verification, "the archive has no Prism.app")
        }
        let identifier = info["CFBundleIdentifier"] as? String
        guard let bundleID, identifier == bundleID else {
            throw UpdateError(.verification, "bundle identifier is \(identifier ?? "missing"), not \(bundleID ?? "missing")")
        }
        let version = info["CFBundleShortVersionString"] as? String
        guard version.flatMap({ AppVersion($0) }) == release.version else {
            throw UpdateError(.verification, "version is \(version ?? "missing"), not \(release.version)")
        }
        if let minimum = info["LSMinimumSystemVersion"] as? String {
            let system = ProcessInfo.processInfo.operatingSystemVersion
            let current = AppVersion(components: [system.majorVersion, system.minorVersion, system.patchVersion])
            guard let required = AppVersion(minimum), required <= current else {
                throw UpdateError(.verification, "needs macOS \(minimum), this Mac has \(current)")
            }
        }
        var code: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(app as CFURL, [], &code)
        guard created == errSecSuccess, let code else {
            throw UpdateError(.verification, "could not read the code signature (\(created))")
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        let validity = SecStaticCodeCheckValidity(code, flags, nil)
        guard validity == errSecSuccess else {
            throw UpdateError(.verification, "the code signature is not valid (\(validity))")
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: @Sendable (Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var failure: Error?

    init(destination: URL, progress: @escaping @Sendable (Int64) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func wait(with continuation: CheckedContinuation<Void, Error>) {
        lock.withLock { self.continuation = continuation }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten)
    }

    /// The file at `location` is deleted when this returns, so it is moved here rather than when the task completes.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        var failure: Error?
        if status != 200 {
            failure = UpdateError(.download, "the server answered \(status)")
        } else {
            do {
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                failure = UpdateError(.download, "could not keep the download: \(error)")
            }
        }
        lock.withLock { self.failure = failure }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, failure) = lock.withLock {
            defer { self.continuation = nil }
            return (self.continuation, self.failure)
        }
        if let error = error ?? failure {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

/// Waits for a line on a pipe, giving up after a timeout or when the pipe closes.
private final class LineWaiter: @unchecked Sendable {
    private let line: Data
    private let lock = NSLock()
    private var received = Data()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(line: String) {
        self.line = Data((line + "\n").utf8)
    }

    func wait(on handle: FileHandle, timeout: TimeInterval) async -> Bool {
        let found = await withCheckedContinuation { continuation in
            lock.withLock { self.continuation = continuation }
            handle.readabilityHandler = { [self] handle in receive(handle.availableData) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in finish(false) }
        }
        handle.readabilityHandler = nil
        return found
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else {
            finish(false)
            return
        }
        let found = lock.withLock {
            received.append(data)
            return received.range(of: line) != nil
        }
        if found {
            finish(true)
        }
    }

    private func finish(_ found: Bool) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: found)
    }
}
