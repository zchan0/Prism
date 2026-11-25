import Foundation
import PrismKit
import Testing
@testable import Prism

@MainActor
struct UpdaterTests {
    private let current = AppVersion("0.3.0")!
    private let newer = Release(
        version: AppVersion("0.3.1")!,
        archiveURL: URL(string: "https://github.com/zchan0/Prism/releases/download/v0.3.1/Prism-0.3.1.zip")!,
        archiveSize: 3_600_000,
        sha256: String(repeating: "a", count: 64),
        notes: "- Something new.",
        pageURL: URL(string: "https://github.com/zchan0/Prism/releases/tag/v0.3.1")!
    )

    // MARK: Versions and the release feed

    @Test func versionsCompareNumberByNumber() {
        let version = AppVersion("0.3.0")!
        #expect(version < AppVersion("0.10.0")!)
        #expect(version == AppVersion("0.3.0")!)
        #expect(version > AppVersion("0.2.9")!)
        #expect(AppVersion("v0.3.1") == AppVersion("0.3.1"))
        #expect(AppVersion("v0.3.1")?.description == "0.3.1")
        for text in ["", "v", "0.3.x", "0..1", "1.2-beta"] {
            #expect(AppVersion(text) == nil, "\(text)")
        }
    }

    @Test func theLatestReleaseIsReadFromGitHubsAnswer() throws {
        let release = try GitHubReleaseFeed.parse(Self.latestJSON(digest: Self.realDigest))
        #expect(release.version == AppVersion("0.3.0")!)
        #expect(release.archiveURL.absoluteString.hasSuffix("/v0.3.0/Prism-0.3.0.zip"))
        #expect(release.sha256 == "ff95cafa69301840b81c33fae364865ee24a2b7ea9aa6e75c0c9c3476dc0c9b1")
        #expect(release.archiveSize == 3_604_467)
        #expect(release.pageURL.absoluteString == "https://github.com/zchan0/Prism/releases/tag/v0.3.0")
        #expect(release.notes.hasPrefix("- Pensieve, a new tool"))
        #expect(release.notes.hasSuffix("the history cleared."))
        #expect(!release.notes.contains("## Install"))
    }

    @Test func aReleaseWithoutADigestIsRejected() {
        #expect(throws: UpdateError.self) { try GitHubReleaseFeed.parse(Self.latestJSON(digest: nil)) }
        #expect(throws: UpdateError.self) { try GitHubReleaseFeed.parse(Self.latestJSON(digest: "md5:abc")) }
    }

    // MARK: Schedule

    @Test func aDailyCheckWaitsADay() async {
        for (hours, checks) in [(23.0, false), (25.0, true)] {
            let setup = Setup(feed: .success(newer), current: current)
            setup.defaults.set(setup.clock.now.addingTimeInterval(-hours * 60 * 60), forKey: "shell.update.lastCheck")
            let updater = setup.updater()
            updater.start()
            await updater.work?.value
            #expect(setup.feed.calls == (checks ? 1 : 0), "\(hours) hours")
        }
    }

    @Test func neverMeansNoCheck() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set("never", forKey: "shell.update.frequency")
        let updater = setup.updater()
        updater.start()
        await updater.work?.value
        #expect(setup.feed.calls == 0)
    }

    // MARK: Checks

    @Test func aFailedBackgroundCheckChangesNothing() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        let checked = setup.clock.now
        #expect(updater.phase == .available(newer))
        #expect(updater.lastCheck == checked)

        setup.feed.result = .failure(URLError(.notConnectedToInternet))
        setup.clock.now = checked.addingTimeInterval(25 * 60 * 60)
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(setup.feed.calls == 2)
        #expect(updater.phase == .available(newer))
        #expect(updater.lastCheck == checked)
    }

    @Test func aFailedCheckThePersonAskedForShowsTheFailure() async {
        let setup = Setup(feed: .failure(URLError(.notConnectedToInternet)), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: true)
        #expect(updater.phase == .checking)
        await updater.work?.value
        #expect(updater.phase == .failed(.check, nil))
        #expect(updater.lastCheck == nil)
        #expect(setup.sleeps.values == [Updater.minimumCheckingTime])
    }

    @Test func aNewVersionIsDownloadedWhenInstallingAutomatically() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        let seen = PhaseBox()
        setup.installer.onDownload = { await MainActor.run { seen.phase = updater.phase } }
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(seen.phase == .downloading(newer, received: 0))
        #expect(updater.phase == .ready(newer))
        #expect(setup.installer.calls == ["download"])
    }

    @Test func aNewVersionWaitsWhenNotInstallingAutomatically() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(updater.phase == .available(newer))
        #expect(setup.installer.calls.isEmpty)
    }

    @Test func aCopyThatCannotReplaceItselfDoesNotDownload() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.canInstall = false
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(updater.phase == .cannotInstall(newer))
        #expect(setup.installer.calls.isEmpty)
    }

    @Test func aDownloadThatFailsVerificationIsNotInstalled() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.downloadError = UpdateError(.verification, "SHA-256 does not match")
        let updater = setup.updater()
        updater.isIdle = { true }
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.tick()
        await updater.work?.value
        #expect(updater.phase == .failed(.verification, newer))
        #expect(setup.installer.calls == ["download"])
    }

    @Test func aCheckFindingTheDownloadedVersionAgainDoesNotDownloadIt() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.check(userInitiated: true)
        await updater.work?.value
        #expect(updater.phase == .ready(newer))
        #expect(setup.installer.calls == ["download"])
    }

    @Test func anUpToDateCheckIsIdle() async {
        let setup = Setup(feed: .success(newer), current: AppVersion("0.3.1")!)
        let updater = setup.updater()
        updater.check(userInitiated: true)
        await updater.work?.value
        #expect(updater.phase == .idle)
        #expect(updater.lastCheck == setup.clock.now)
    }

    // MARK: Installing

    @Test func aDownloadedUpdateWaitsUntilPrismIsIdle() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.isIdle = { false }
        updater.tick()
        await updater.work?.value
        #expect(updater.phase == .ready(newer))
        #expect(setup.installer.calls == ["download"])
    }

    @Test func aDownloadedUpdateIsInstalledOnceIdle() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.isIdle = { true }
        updater.tick()
        #expect(updater.phase == .installing(newer))
        await updater.work?.value
        #expect(setup.installer.calls == ["download", "install", "cleanUp", "relaunch", "terminate"])
        #expect(setup.defaults.string(forKey: "shell.update.installedVersion") == "0.3.1")
        #expect(setup.defaults.object(forKey: "shell.update.installedAt") as? Date == setup.clock.now)
        #expect(setup.defaults.string(forKey: "shell.update.installedNotes") == newer.notes)
        #expect(setup.defaults.object(forKey: "shell.update.reopensWindow") == nil)
    }

    @Test func updatingByHandInstallsWithoutWaitingForATick() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.update()
        #expect(updater.phase == .downloading(newer, received: 0))
        await updater.work?.value
        #expect(setup.installer.calls == ["download", "install", "cleanUp", "relaunch", "terminate"])
        #expect(setup.defaults.bool(forKey: "shell.update.reopensWindow"))
    }

    @Test func theUpdateThatStartedThisVersionIsRecentForADay() {
        for (hours, isRecent) in [(1.0, true), (25.0, false)] {
            let setup = Setup(feed: .success(newer), current: current)
            let installedAt = setup.clock.now.addingTimeInterval(-hours * 60 * 60)
            setup.defaults.set("0.3.0", forKey: "shell.update.installedVersion")
            setup.defaults.set(installedAt, forKey: "shell.update.installedAt")
            setup.defaults.set("- Pensieve.", forKey: "shell.update.installedNotes")
            setup.defaults.set(newer.pageURL.absoluteString, forKey: "shell.update.installedPage")
            let recent = setup.updater().recentUpdate
            #expect((recent != nil) == isRecent, "\(hours) hours")
            if isRecent {
                #expect(recent == Updater.RecentUpdate(version: current, date: installedAt, notes: "- Pensieve.", pageURL: newer.pageURL))
            }
        }
    }

    @Test func installingKeepsTheReleasePageForWhatsNew() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.installNow()
        await updater.work?.value
        #expect(setup.defaults.string(forKey: "shell.update.installedPage") == newer.pageURL.absoluteString)
    }

    @Test func theUpdateButtonsDownloadIsMarkedAsInstallingRightAway() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        setup.installer.downloadError = UpdateError(.download, "stopped")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(!updater.installsWhenDownloaded)
        updater.update()
        #expect(updater.installsWhenDownloaded)
        await updater.work?.value
        #expect(updater.phase == .failed(.download, newer))
        #expect(updater.installsWhenDownloaded)
    }

    @Test func turningInstallingAutomaticallyOnDownloadsTheWaitingVersion() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(updater.phase == .available(newer))
        updater.setInstallsAutomatically(true)
        #expect(updater.phase == .downloading(newer, received: 0))
        #expect(!updater.installsWhenDownloaded)
        await updater.work?.value
        #expect(updater.phase == .ready(newer))
        #expect(setup.defaults.object(forKey: "shell.update.installsAutomatically") as? Bool == true)

        updater.setInstallsAutomatically(false)
        updater.setInstallsAutomatically(true)
        #expect(setup.installer.calls == ["download"])
    }

    @Test func tryingAgainDownloadsAgain() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.downloadError = UpdateError(.verification, "SHA-256 does not match")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(updater.phase == .failed(.verification, newer))

        setup.installer.downloadError = nil
        updater.retry()
        await updater.work?.value
        #expect(updater.phase == .ready(newer))
        #expect(setup.installer.calls == ["download", "download"])
    }

    @Test func tryingAgainAfterAFailedInstallationInstallsRightAway() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.installError = UpdateError(.install, "could not replace")
        let updater = setup.updater()
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.installNow()
        await updater.work?.value
        #expect(updater.phase == .failed(.install, newer))

        setup.installer.installError = nil
        updater.retry()
        await updater.work?.value
        #expect(setup.installer.calls == ["download", "install", "download", "install", "cleanUp", "relaunch", "terminate"])
    }

    @Test func tryingAgainAfterAFailedCheckChecks() async {
        let setup = Setup(feed: .failure(URLError(.notConnectedToInternet)), current: current)
        let updater = setup.updater()
        updater.check(userInitiated: true)
        await updater.work?.value
        #expect(updater.phase == .failed(.check, nil))

        setup.feed.result = .success(newer)
        updater.retry()
        #expect(updater.phase == .checking)
        await updater.work?.value
        #expect(setup.feed.calls == 2)
        #expect(updater.phase == .ready(newer))
    }

    @Test func theListAndThePanelSayWhenAnUpdateWaits() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.defaults.set(false, forKey: "shell.update.installsAutomatically")
        let updater = setup.updater()
        #expect(updater.attentionBadge == nil)
        updater.check(userInitiated: false)
        await updater.work?.value
        #expect(updater.attentionBadge == "Update available")
        updater.setInstallsAutomatically(true)
        await updater.work?.value
        #expect(updater.attentionBadge == "Update ready")
    }

    @Test func theToolsAreAskedWhatToHoldOnceTheNewVersionIsInPlace() async {
        let setup = Setup(feed: .success(newer), current: current)
        let updater = setup.updater()
        let installer = setup.installer
        updater.prepareForRelaunch = {
            installer.record("hold")
            return RelaunchHold(keepsSystemAwake: true, heldFiles: ["/tmp/flag"])
        }
        updater.relaunchCancelled = { installer.record("cancelled") }
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.installNow()
        await updater.work?.value
        #expect(setup.installer.calls == ["download", "install", "cleanUp", "hold", "relaunch", "terminate"])
        #expect(setup.installer.lastHold == RelaunchHold(keepsSystemAwake: true, heldFiles: ["/tmp/flag"]))
    }

    @Test func aFailedReplacementAsksTheToolsForNothing() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.installError = UpdateError(.install, "could not replace")
        let updater = setup.updater()
        let installer = setup.installer
        updater.prepareForRelaunch = {
            installer.record("hold")
            return RelaunchHold()
        }
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.installNow()
        await updater.work?.value
        #expect(updater.phase == .failed(.install, newer))
        #expect(setup.installer.calls == ["download", "install"])
    }

    @Test func aRelaunchThatDoesNotTakeOverLeavesThisProcessRunning() async {
        let setup = Setup(feed: .success(newer), current: current)
        setup.installer.relaunchError = UpdateError(.install, "the relaunch did not take over in 2 s")
        let updater = setup.updater()
        let installer = setup.installer
        updater.prepareForRelaunch = {
            installer.record("hold")
            return RelaunchHold(keepsSystemAwake: true)
        }
        updater.relaunchCancelled = { installer.record("cancelled") }
        updater.check(userInitiated: false)
        await updater.work?.value
        updater.installNow()
        await updater.work?.value
        #expect(updater.phase == .failed(.install, newer))
        #expect(setup.installer.calls == ["download", "install", "cleanUp", "hold", "relaunch", "cancelled"])
    }

    @Test func theToolsThatBlockARelaunchComeFromTheApp() {
        let updater = Setup(feed: .success(newer), current: current).updater()
        #expect(updater.toolsBlockingRelaunch.isEmpty)
        updater.blockingTools = { ["Lumos"] }
        #expect(updater.toolsBlockingRelaunch == ["Lumos"])
    }

    // MARK: Fixture

    private static let realDigest = "sha256:ff95cafa69301840b81c33fae364865ee24a2b7ea9aa6e75c0c9c3476dc0c9b1"

    /// GitHub's answer for 0.3.0, without the fields the feed does not read and with a shorter body.
    private static func latestJSON(digest: String?) -> Data {
        let digestField = digest.map { #""digest": "\#($0)","# } ?? ""
        return Data(#"""
        {
          "html_url": "https://github.com/zchan0/Prism/releases/tag/v0.3.0",
          "tag_name": "v0.3.0",
          "name": "0.3.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {
              "name": "Prism-0.3.0.zip",
              "content_type": "application/zip",
              "size": 3604467,
              \#(digestField)
              "browser_download_url": "https://github.com/zchan0/Prism/releases/download/v0.3.0/Prism-0.3.0.zip"
            },
            {
              "name": "Prism-0.3.0.zip.sha256",
              "content_type": "application/octet-stream",
              "size": 82,
              "digest": "sha256:61f03df370d123b7c6c56096aa05b1afb4442dae7f34a383a0657c283a605073",
              "browser_download_url": "https://github.com/zchan0/Prism/releases/download/v0.3.0/Prism-0.3.0.zip.sha256"
            }
          ],
          "body": "- Pensieve, a new tool: a history of the last 200 things you copied, whether text, pictures, files or colors. ⇧⌘V opens it in the middle of the screen, and the app you were in stays in front. Return puts an item back on the clipboard with all its formats, for you to paste.\n- Pensieve searches text, file names and colors, and leaves out what apps mark as private, such as passwords. It saves the history in ~/Library/Application Support/Prism/Pensieve, a folder only you can open, without encryption. Recording can be paused, and the history cleared.\n\n## Install\n\n1. Download `Prism-0.3.0.zip` below, unzip it, and drag `Prism.app` into Applications.\n2. Open the app. macOS says it cannot verify the developer, because Prism is not notarized by Apple: click Done.\n3. Open System Settings → Privacy & Security. Near the bottom, find Prism, click Open Anyway, and confirm.\n\nInstead of steps 2 and 3, you can run `xattr -dr com.apple.quarantine /Applications/Prism.app` once.\n\nPrism needs macOS 14 or later, on Apple silicon or Intel. SHA-256 of `Prism-0.3.0.zip`: `ff95cafa69301840b81c33fae364865ee24a2b7ea9aa6e75c0c9c3476dc0c9b1`\n"
        }
        """#.utf8)
    }
}

/// One updater with fakes for everything outside it.
@MainActor
private final class Setup {
    let feed: FakeFeed
    let installer = FakeInstaller()
    let defaults = MemoryDefaults()
    let clock = Clock()
    let sleeps = Sleeps()
    let current: AppVersion

    init(feed: Result<Release, Error>, current: AppVersion) {
        self.feed = FakeFeed(feed)
        self.current = current
    }

    func updater() -> Updater {
        let installer = installer
        let clock = clock
        let sleeps = sleeps
        return Updater(
            feed: feed,
            installer: installer,
            defaults: defaults,
            currentVersion: current,
            isAvailable: true,
            checksAtLaunch: false,
            scheduler: FakeScheduler(),
            now: { clock.now },
            sleep: { sleeps.append($0) },
            terminate: { installer.record("terminate") }
        )
    }
}

@MainActor
private final class Clock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

@MainActor
private final class PhaseBox {
    var phase: Updater.Phase?
}

@MainActor
private final class FakeScheduler: Ticking {
    func start(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func stop() {}
}

private final class Sleeps: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [TimeInterval] = []

    var values: [TimeInterval] { lock.withLock { recorded } }

    func append(_ value: TimeInterval) {
        lock.withLock { recorded.append(value) }
    }
}

private final class FakeFeed: ReleaseFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Result<Release, Error>
    private var count = 0

    init(_ result: Result<Release, Error>) {
        stored = result
    }

    var result: Result<Release, Error> {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    var calls: Int { lock.withLock { count } }

    func latest() async throws -> Release {
        try lock.withLock {
            count += 1
            return try stored.get()
        }
    }
}

private final class FakeInstaller: UpdateInstalling, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private var installable = true
    private var error: Error?
    private var installFailure: Error?
    private var relaunchFailure: Error?
    private var hold: RelaunchHold?
    private var downloadHook: (@Sendable () async -> Void)?

    var calls: [String] { lock.withLock { recorded } }

    var installError: Error? {
        get { lock.withLock { installFailure } }
        set { lock.withLock { installFailure = newValue } }
    }

    var canInstall: Bool {
        get { lock.withLock { installable } }
        set { lock.withLock { installable = newValue } }
    }

    var downloadError: Error? {
        get { lock.withLock { error } }
        set { lock.withLock { error = newValue } }
    }

    var onDownload: (@Sendable () async -> Void)? {
        get { lock.withLock { downloadHook } }
        set { lock.withLock { downloadHook = newValue } }
    }

    func record(_ call: String) {
        lock.withLock { recorded.append(call) }
    }

    func download(_ release: Release, progress: @escaping @Sendable (Int64) -> Void) async throws -> URL {
        record("download")
        await onDownload?()
        if let downloadError { throw downloadError }
        return URL(fileURLWithPath: "/tmp/Update/Unpacked/Prism.app")
    }

    func install(_ stagedApp: URL) async throws {
        record("install")
        if let installError { throw installError }
    }

    var relaunchError: Error? {
        get { lock.withLock { relaunchFailure } }
        set { lock.withLock { relaunchFailure = newValue } }
    }

    var lastHold: RelaunchHold? { lock.withLock { hold } }

    func relaunch(holding hold: RelaunchHold) async throws {
        record("relaunch")
        lock.withLock { self.hold = hold }
        if let relaunchError { throw relaunchError }
    }

    func cleanUp() {
        record("cleanUp")
    }
}
