import AppKit
import Foundation
import Observation
import os
import PrismKit

/// The ways an update can fail that the interface tells apart.
enum UpdateFailure: Equatable, Sendable {
    case check
    case download
    case verification
    case install
}

struct UpdateError: Error, CustomStringConvertible {
    let failure: UpdateFailure
    let reason: String

    init(_ failure: UpdateFailure, _ reason: String) {
        self.failure = failure
        self.reason = reason
    }

    var description: String { "\(failure) failed: \(reason)" }
}

/// Looks for a newer Prism on GitHub, downloads it, and puts it in place of this one.
///
/// With installing automatically on, a newer version is downloaded as soon as a check finds it, and installed the
/// next time Prism is idle: no Prism window or panel open and no tool busy with something a relaunch would cut short.
/// Installing replaces the app on disk, opens it again and quits this process.
@MainActor
@Observable
final class Updater {
    typealias Failure = UpdateFailure

    enum Phase: Equatable {
        /// Up to date, or not checked yet.
        case idle
        /// Only a check the person asked for shows this.
        case checking
        /// A newer version waits for the person: installing automatically is off, or they cancelled the download.
        case available(Release)
        case downloading(Release, received: Int64)
        /// Downloaded and verified.
        case ready(Release)
        case installing(Release)
        case failed(Failure, Release?)
        /// This copy cannot replace itself, such as one opened from a read-only disk image.
        case cannotInstall(Release)
    }

    enum Frequency: String, CaseIterable, Sendable {
        case daily
        case weekly
        case monthly
        case never

        var interval: TimeInterval? {
            switch self {
            case .daily: 24 * 60 * 60
            case .weekly: 7 * 24 * 60 * 60
            case .monthly: 30 * 24 * 60 * 60
            case .never: nil
            }
        }
    }

    /// The update this process came from, for a day after it was installed.
    struct RecentUpdate: Equatable {
        let version: AppVersion
        let date: Date
        let notes: String
        let pageURL: URL?
    }

    private enum Key {
        static let frequency = "shell.update.frequency"
        static let installsAutomatically = "shell.update.installsAutomatically"
        static let lastCheck = "shell.update.lastCheck"
        static let installedVersion = "shell.update.installedVersion"
        static let installedAt = "shell.update.installedAt"
        static let installedNotes = "shell.update.installedNotes"
        static let installedPage = "shell.update.installedPage"
        static let reopensWindow = "shell.update.reopensWindow"
    }

    #if DEBUG
    /// A debug build updates only when asked to, and then checks at once, so trying it does not wait for the schedule.
    static let isAvailableHere = ProcessInfo.processInfo.environment["PRISM_UPDATE"] == "1"
    static let checksAtLaunchHere = isAvailableHere
    /// Installs a downloaded update this many seconds after launch at the earliest, as a click on Install and
    /// Relaunch would, so a test can update while a tool is busy, which installing automatically waits out.
    static let installsByHandAfter = ProcessInfo.processInfo.environment["PRISM_UPDATE_INSTALL_NOW"].flatMap { TimeInterval($0) }
    #else
    static let isAvailableHere = Bundle.main.bundleIdentifier != nil
    static let checksAtLaunchHere = false
    #endif

    static let minimumCheckingTime: TimeInterval = 0.6
    static let scheduleInterval: TimeInterval = 60 * 60

    private(set) var phase: Phase = .idle
    private(set) var frequency: Frequency
    private(set) var installsAutomatically: Bool
    /// The last check that reached GitHub; failed checks leave it alone.
    private(set) var lastCheck: Date?
    /// Whether the download under way, or the one that failed last, installs as soon as it is done: the person
    /// clicked Update rather than waiting for Prism to be idle.
    private(set) var installsWhenDownloaded = false
    /// The person installed the update that started this process, so it opens the Prism window where they were.
    /// Read by `start()`.
    @ObservationIgnored private(set) var reopensWindow = false
    @ObservationIgnored private(set) var isAvailable: Bool
    @ObservationIgnored let currentVersion: AppVersion?
    /// Whether installing now would interrupt nothing. The app sets it.
    @ObservationIgnored var isIdle: @MainActor () -> Bool = { false }
    /// The names of the tools a relaunch would interrupt now. The app sets it.
    @ObservationIgnored var blockingTools: @MainActor () -> [String] = { [] }
    /// Asks the tools to save what carries over the relaunch, and returns what has to be held for them in between.
    /// Called once the new version is in place, right before relaunching. The app sets it.
    @ObservationIgnored var prepareForRelaunch: @MainActor () -> RelaunchHold = { RelaunchHold() }
    /// The relaunch did not happen after `prepareForRelaunch`: the tools carry on in this process. The app sets it.
    @ObservationIgnored var relaunchCancelled: @MainActor () -> Void = {}
    /// The check, download or installation started last, for a test to wait on.
    @ObservationIgnored private(set) var work: Task<Void, Never>?

    @ObservationIgnored private let feed: ReleaseFetching
    @ObservationIgnored private let installer: UpdateInstalling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let checksAtLaunch: Bool
    @ObservationIgnored private let scheduler: Ticking
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let sleep: @Sendable (TimeInterval) async -> Void
    @ObservationIgnored private let terminate: @MainActor () -> Void
    @ObservationIgnored private var download: Task<URL, Error>?
    @ObservationIgnored private var staged: (release: Release, app: URL)?
    #if DEBUG
    @ObservationIgnored private var preview: Preview?
    @ObservationIgnored private var launchedAt: Date?
    #endif

    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "update")

    init(
        feed: ReleaseFetching = GitHubReleaseFeed(),
        installer: UpdateInstalling = UpdateInstaller(),
        defaults: UserDefaults = .standard,
        currentVersion: AppVersion? = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap { AppVersion($0) },
        isAvailable: Bool = Updater.isAvailableHere,
        checksAtLaunch: Bool = Updater.checksAtLaunchHere,
        scheduler: Ticking = Ticker(),
        now: @escaping @MainActor () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
        terminate: @escaping @MainActor () -> Void = { NSApp.terminate(nil) }
    ) {
        self.feed = feed
        self.installer = installer
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.isAvailable = isAvailable
        self.checksAtLaunch = checksAtLaunch
        self.scheduler = scheduler
        self.now = now
        self.sleep = sleep
        self.terminate = terminate
        frequency = defaults.string(forKey: Key.frequency).flatMap(Frequency.init(rawValue:)) ?? .daily
        installsAutomatically = defaults.object(forKey: Key.installsAutomatically) as? Bool ?? true
        lastCheck = defaults.object(forKey: Key.lastCheck) as? Date
    }

    var needsAttention: Bool {
        switch phase {
        case .available, .ready, .cannotInstall, .failed(_, .some): true
        default: false
        }
    }

    var recentUpdate: RecentUpdate? {
        #if DEBUG
        if let preview { return preview.recentUpdate }
        #endif
        guard let currentVersion,
              let installed = defaults.string(forKey: Key.installedVersion).flatMap({ AppVersion($0) }),
              installed == currentVersion,
              let date = defaults.object(forKey: Key.installedAt) as? Date,
              now().timeIntervalSince(date) < 24 * 60 * 60 else { return nil }
        return RecentUpdate(
            version: installed,
            date: date,
            notes: defaults.string(forKey: Key.installedNotes) ?? "",
            pageURL: defaults.string(forKey: Key.installedPage).flatMap { URL(string: $0) }
        )
    }

    var toolsBlockingRelaunch: [String] {
        #if DEBUG
        if let blocking = preview?.blockingTools { return blocking }
        #endif
        return blockingTools()
    }

    func setFrequency(_ frequency: Frequency) {
        guard !isPreview else { return }
        self.frequency = frequency
        defaults.set(frequency.rawValue, forKey: Key.frequency)
    }

    /// Turning it on while a newer version waits starts downloading it.
    func setInstallsAutomatically(_ isOn: Bool) {
        guard !isPreview else { return }
        installsAutomatically = isOn
        defaults.set(isOn, forKey: Key.installsAutomatically)
        if isOn, case .available(let release) = phase {
            work = startDownload(release, installsWhenDone: false)
        }
    }

    func start() {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["PRISM_UPDATE_PHASE"] {
            showPreview(name)
            return
        }
        launchedAt = now()
        #endif
        reopensWindow = defaults.bool(forKey: Key.reopensWindow)
        defaults.removeObject(forKey: Key.reopensWindow)
        guard isAvailable else { return }
        installer.cleanUp()
        if checksAtLaunch {
            check(userInitiated: false)
        } else {
            checkIfDue()
        }
        scheduler.start(every: Self.scheduleInterval) { [weak self] in self?.checkIfDue() }
    }

    func check(userInitiated: Bool) {
        guard isAvailable, !isPreview else { return }
        switch phase {
        case .checking, .downloading, .installing: return
        default: break
        }
        if userInitiated {
            setPhase(.checking)
        }
        work = Task { await runCheck(userInitiated: userInitiated) }
    }

    /// Downloads the available version and installs it right away, without waiting for Prism to be idle.
    func update() {
        guard !isPreview, case .available(let release) = phase else { return }
        work = startDownload(release, installsWhenDone: true)
    }

    /// After a failure: checks again, or downloads the release again. A download the person started with Update
    /// installs right away again, and so does one whose installation failed.
    func retry() {
        guard !isPreview, case .failed(let failure, let release) = phase else { return }
        switch (failure, release) {
        case (.check, _):
            check(userInitiated: true)
        case (.install, let release?):
            work = startDownload(release, installsWhenDone: true)
        case (_, let release?):
            work = startDownload(release, installsWhenDone: installsWhenDownloaded)
        default:
            break
        }
    }

    func cancelDownload() {
        guard !isPreview, case .downloading(let release, _) = phase else { return }
        download?.cancel()
        download = nil
        setPhase(.available(release))
    }

    func installNow() {
        guard !isPreview, case .ready = phase else { return }
        startInstall(byHand: true)
    }

    /// Called once a second: installs a downloaded update automatically once Prism is idle.
    func tick() {
        #if DEBUG
        if case .ready = phase, let delay = Self.installsByHandAfter, let launchedAt,
           now().timeIntervalSince(launchedAt) >= delay {
            startInstall(byHand: true)
            return
        }
        #endif
        guard !isPreview, case .ready = phase, installsAutomatically, isIdle() else { return }
        startInstall(byHand: false)
    }

    /// A screenshot's made-up state, which reaches neither GitHub, nor the disk, nor the settings.
    private var isPreview: Bool {
        #if DEBUG
        preview != nil
        #else
        false
        #endif
    }

    private var isDue: Bool {
        guard let interval = frequency.interval else { return false }
        guard let lastCheck else { return true }
        return now().timeIntervalSince(lastCheck) >= interval
    }

    private func checkIfDue() {
        if isDue {
            check(userInitiated: false)
        }
    }

    private func runCheck(userInitiated: Bool) async {
        let started = now()
        let result: Result<Release, Error>
        do {
            result = .success(try await feed.latest())
        } catch {
            result = .failure(error)
        }
        if userInitiated {
            let remaining = Self.minimumCheckingTime - now().timeIntervalSince(started)
            if remaining > 0 {
                await sleep(remaining)
            }
        }

        let release: Release
        switch result {
        case .success(let found):
            release = found
        case .failure(let error):
            Self.logger.notice("check failed: \(String(describing: error), privacy: .public)")
            if userInitiated {
                setPhase(.failed(.check, nil))
            }
            return
        }
        let checked = now()
        lastCheck = checked
        defaults.set(checked, forKey: Key.lastCheck)

        switch phase {
        case .downloading, .installing: return
        default: break
        }
        guard let currentVersion, release.version > currentVersion else {
            setPhase(.idle)
            return
        }
        if let staged, staged.release.version == release.version {
            setPhase(.ready(staged.release))
            return
        }
        guard installer.canInstall else {
            setPhase(.cannotInstall(release))
            return
        }
        if installsAutomatically {
            await startDownload(release, installsWhenDone: false).value
        } else {
            setPhase(.available(release))
        }
    }

    /// The phase changes before this returns, so a second click cannot start a second download.
    private func startDownload(_ release: Release, installsWhenDone: Bool) -> Task<Void, Never> {
        staged = nil
        installsWhenDownloaded = installsWhenDone
        setPhase(.downloading(release, received: 0))
        let download = Task { [installer] in
            try await installer.download(release) { received in
                Task { @MainActor [weak self] in self?.received(received, of: release) }
            }
        }
        self.download = download
        return Task {
            let result = await download.result
            // Cancelled, or replaced by a newer download.
            guard self.download == download else { return }
            self.download = nil
            switch result {
            case .success(let app):
                staged = (release, app)
                setPhase(.ready(release))
                if installsWhenDone {
                    setPhase(.installing(release))
                    await install(release, from: app, byHand: true)
                }
            case .failure(let error):
                let failure = (error as? UpdateError)?.failure ?? .download
                let description = (error as? UpdateError)?.description ?? "\(failure) failed: \(error)"
                Self.logger.notice("\(description, privacy: .public)")
                setPhase(.failed(failure, release))
            }
        }
    }

    private func received(_ bytes: Int64, of release: Release) {
        guard case .downloading(let current, let received) = phase, current == release, bytes > received else { return }
        phase = .downloading(release, received: bytes)
    }

    /// The phase changes before this returns, so the next tick cannot start a second installation.
    private func startInstall(byHand: Bool) {
        guard let staged else { return }
        setPhase(.installing(staged.release))
        work = Task { await install(staged.release, from: staged.app, byHand: byHand) }
    }

    private func install(_ release: Release, from app: URL, byHand: Bool) async {
        defaults.set(release.version.description, forKey: Key.installedVersion)
        defaults.set(now(), forKey: Key.installedAt)
        defaults.set(release.notes, forKey: Key.installedNotes)
        defaults.set(release.pageURL.absoluteString, forKey: Key.installedPage)
        if byHand {
            defaults.set(true, forKey: Key.reopensWindow)
        }
        do {
            try await installer.install(app)
            staged = nil
            installer.cleanUp()
            let hold = prepareForRelaunch()
            do {
                try await installer.relaunch(holding: hold)
            } catch {
                relaunchCancelled()
                throw error
            }
        } catch {
            defaults.removeObject(forKey: Key.reopensWindow)
            Self.logger.notice("install failed: \(String(describing: error), privacy: .public)")
            setPhase(.failed(.install, release))
            return
        }
        Self.logger.notice("installed \(release.version.description, privacy: .public), relaunching")
        terminate()
    }

    private func setPhase(_ phase: Phase) {
        let changed = phase.name != self.phase.name
        self.phase = phase
        if changed {
            Self.logger.notice("phase: \(phase.name, privacy: .public)")
        }
    }
}

#if DEBUG
extension Updater {
    /// What `PRISM_UPDATE_PHASE` makes up besides the phase.
    fileprivate struct Preview {
        var recentUpdate: RecentUpdate?
        var blockingTools: [String]?
    }

    /// Puts the updater in a made-up state for a screenshot: version 0.3.1, 39% downloaded, last checked two hours
    /// ago. Nothing is saved, and the updater does nothing afterwards.
    fileprivate func showPreview(_ name: String) {
        let release = Release(
            version: AppVersion(components: [0, 3, 1]),
            archiveURL: URL(string: "https://github.com/zchan0/Prism/releases/download/v0.3.1/Prism-0.3.1.zip")!,
            archiveSize: 3_600_000,
            sha256: String(repeating: "0", count: 64),
            notes: "- Prism updates itself.\n- A sample line with *emphasis* and a [link](https://github.com/zchan0/Prism).",
            pageURL: URL(string: "https://github.com/zchan0/Prism/releases/tag/v0.3.1")!
        )
        let twoHoursAgo = now().addingTimeInterval(-2 * 60 * 60)
        var preview = Preview()
        isAvailable = true
        lastCheck = twoHoursAgo
        frequency = .daily
        installsAutomatically = true
        switch name {
        case "idle": phase = .idle
        case "never": frequency = .never
        case "unchecked": lastCheck = nil
        case "checking": phase = .checking
        case "available":
            installsAutomatically = false
            phase = .available(release)
        case "downloading": phase = .downloading(release, received: release.archiveSize * 39 / 100)
        case "ready": phase = .ready(release)
        case "readyBlocked":
            preview.blockingTools = ["Lumos"]
            phase = .ready(release)
        case "readyManual":
            installsAutomatically = false
            phase = .ready(release)
        case "installing": phase = .installing(release)
        case "updated":
            preview.recentUpdate = RecentUpdate(
                version: currentVersion ?? release.version,
                date: twoHoursAgo,
                notes: release.notes,
                pageURL: release.pageURL
            )
        case "checkFailed": phase = .failed(.check, nil)
        case "downloadFailed": phase = .failed(.download, release)
        case "verifyFailed": phase = .failed(.verification, release)
        case "installFailed": phase = .failed(.install, release)
        case "cannotInstall": phase = .cannotInstall(release)
        case "unavailable": isAvailable = false
        default: print("PRISM_UPDATE_PHASE: no phase named \(name)")
        }
        self.preview = preview
    }
}
#endif

private extension Updater.Phase {
    /// The phase without the download's progress, so the log gets one line per phase.
    var name: String {
        switch self {
        case .idle: "idle"
        case .checking: "checking"
        case .available(let release): "available \(release.version)"
        case .downloading(let release, _): "downloading \(release.version)"
        case .ready(let release): "ready \(release.version)"
        case .installing(let release): "installing \(release.version)"
        case .failed(let failure, let release): "failed \(failure)" + (release.map { " \($0.version)" } ?? "")
        case .cannotInstall(let release): "cannot install \(release.version)"
        }
    }
}
