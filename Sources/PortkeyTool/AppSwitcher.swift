import AppKit
import os

enum AppSwitcher {
    /// `savedURL` tells apart two copies with one bundle id, such as Xcode and Xcode beta.
    struct Target: Equatable, Sendable {
        let bundleID: String
        let savedURL: URL?
    }

    struct RunningApp: Equatable, Sendable {
        let pid: pid_t
        let bundleURL: URL?
    }

    enum Decision: Equatable, Sendable {
        case hide(pid: pid_t)
        case open(URL)
        case nothing
    }

    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "Portkey")

    /// `running` holds only the instances with the target's bundle id; `installedURL` is where Launch Services finds
    /// that bundle id.
    static func decide(
        savedURL: URL?,
        savedURLExists: Bool,
        running: [RunningApp],
        frontmostPID: pid_t?,
        installedURL: URL?
    ) -> Decision {
        let match: RunningApp?
        let fallbackURL: URL?
        if let savedURL, savedURLExists {
            let savedPath = savedURL.standardizedFileURL.path
            match = running.first { $0.bundleURL?.standardizedFileURL.path == savedPath }
            fallbackURL = savedURL
        } else {
            match = running.first
            fallbackURL = installedURL
        }

        if let match, match.pid == frontmostPID {
            return .hide(pid: match.pid)
        }
        guard let url = match?.bundleURL ?? fallbackURL else { return .nothing }
        return .open(url)
    }

    @MainActor
    static func switchTo(_ target: Target) {
        let workspace = NSWorkspace.shared
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID)
            .filter { !$0.isTerminated }
        let decision = decide(
            savedURL: target.savedURL,
            savedURLExists: target.savedURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false,
            running: instances.map { RunningApp(pid: $0.processIdentifier, bundleURL: $0.bundleURL) },
            frontmostPID: workspace.frontmostApplication?.processIdentifier,
            installedURL: workspace.urlForApplication(withBundleIdentifier: target.bundleID)
        )

        switch decision {
        case .hide(let pid):
            instances.first { $0.processIdentifier == pid }?.hide()
        case .open(let url):
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            workspace.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    logger.error("Opening \(url.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        case .nothing:
            break
        }
    }
}
