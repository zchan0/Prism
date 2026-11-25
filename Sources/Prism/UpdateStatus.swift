import Foundation
import PrismKit

/// What the status card at the top of About shows for the updater's state, apart from how it is drawn.
struct UpdateStatusContent: Equatable {
    enum Tone: Equatable {
        case green
        case blue
        case amber
        case neutral
    }

    enum Glyph: Equatable {
        case checkmark
        case arrowDown
        case exclamation
        case dash
        case spinner
    }

    enum Action: Equatable {
        case check
        case update
        case cancelDownload
        case installNow
        /// Checks or downloads again after a failure.
        case retry
        case open(URL)
    }

    /// What follows the note, as a link of its own.
    enum Link: Equatable {
        case whatsNew(WhatsNew)
        case download(URL)

        var title: String {
            switch self {
            case .whatsNew: Strings.whatsNew
            case .download: Strings.downloadFromGitHub
            }
        }
    }

    struct Button: Equatable {
        let title: String
        let isProminent: Bool
        let isEnabled: Bool
        let action: Action

        init(_ title: String, isProminent: Bool = false, isEnabled: Bool = true, action: Action) {
            self.title = title
            self.isProminent = isProminent
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    struct Progress: Equatable {
        let fraction: Double
        /// "1.4 MB / 3.6 MB".
        let text: String
    }

    /// Everything the card depends on.
    struct Context {
        var phase: Updater.Phase
        var isAvailable: Bool
        var currentVersion: AppVersion?
        var lastCheck: Date?
        var frequency: Updater.Frequency
        var installsAutomatically: Bool
        var installsWhenDownloaded: Bool
        var recentUpdate: Updater.RecentUpdate?
        var blockingTools: [String]
        var isWindowOpen: Bool
        /// How long ago a date was, such as "2 hours ago".
        var relative: (Date) -> String = { $0.formatted(.relative(presentation: .named)) }
    }

    var tone: Tone
    var glyph: Glyph
    var title: String
    var note: String
    var link: Link?
    var button: Button?
    var progress: Progress?

    static func content(for context: Context) -> UpdateStatusContent {
        let current = context.currentVersion?.description ?? "dev"
        guard context.isAvailable else {
            return UpdateStatusContent(tone: .neutral, glyph: .dash, title: "\(Strings.appName) dev", note: Strings.developmentBuild)
        }
        let checkNow = Button(Strings.checkNow, action: .check)
        switch context.phase {
        case .idle:
            let title = "\(Strings.appName) \(current)"
            if let recent = context.recentUpdate {
                return UpdateStatusContent(
                    tone: .green, glyph: .checkmark, title: title,
                    note: withSeparator(Strings.updated(context.relative(recent.date))),
                    link: .whatsNew(WhatsNew(version: recent.version, notes: recent.notes, pageURL: recent.pageURL)),
                    button: checkNow
                )
            }
            let note: String
            if let lastCheck = context.lastCheck {
                let time = context.relative(lastCheck)
                note = context.frequency == .never
                    ? Strings.automaticChecksOff(lastChecked: time)
                    : Strings.upToDate(lastChecked: time)
            } else {
                note = Strings.notCheckedYet
            }
            return UpdateStatusContent(tone: .green, glyph: .checkmark, title: title, note: note, button: checkNow)

        case .checking:
            return UpdateStatusContent(tone: .neutral, glyph: .spinner, title: Strings.checkingForUpdates, note: Strings.youHave(current))

        case .available(let release):
            return UpdateStatusContent(
                tone: .blue, glyph: .arrowDown, title: Strings.updateAvailable(release.version.description),
                note: withSeparator(Strings.youHave(current)),
                link: .whatsNew(WhatsNew(release)),
                button: Button(Strings.update, isProminent: true, action: .update)
            )

        case .downloading(let release, let received):
            return UpdateStatusContent(
                tone: .blue, glyph: .arrowDown, title: Strings.downloading(release.version.description),
                note: context.installsWhenDownloaded ? Strings.installsWhenDownloaded : Strings.installsWhenIdle,
                button: Button(Strings.cancel, action: .cancelDownload),
                progress: progress(received: received, total: release.archiveSize)
            )

        case .ready(let release):
            let note: String
            if !context.installsAutomatically {
                note = Strings.downloadedAndReady
            } else if !context.blockingTools.isEmpty {
                note = Strings.installsWhenFinished(context.blockingTools.formatted(.list(type: .and)))
            } else if context.isWindowOpen {
                note = Strings.installsWhenWindowCloses
            } else {
                note = Strings.installsWhenIdle
            }
            return UpdateStatusContent(
                tone: .blue, glyph: .arrowDown, title: Strings.updateReady(release.version.description),
                note: withSeparator(note),
                link: .whatsNew(WhatsNew(release)),
                // A busy tool only holds back installing automatically: a relaunch carries its work over.
                button: Button(Strings.installAndRelaunch, isProminent: true, action: .installNow)
            )

        case .installing(let release):
            let note = context.blockingTools.isEmpty
                ? Strings.willReopen
                : Strings.willReopenKeepsRunning(context.blockingTools.formatted(.list(type: .and)))
            return UpdateStatusContent(
                tone: .blue, glyph: .spinner, title: Strings.installing(release.version.description), note: note
            )

        case .failed(.download, let release?):
            return UpdateStatusContent(
                tone: .amber, glyph: .exclamation, title: Strings.couldNotDownload(release.version.description),
                note: Strings.downloadStopped,
                link: .download(release.pageURL),
                button: Button(Strings.tryAgain, action: .retry)
            )

        case .failed(.verification, let release?):
            return UpdateStatusContent(
                tone: .amber, glyph: .exclamation, title: Strings.failedVerification(release.version.description),
                note: Strings.downloadDeleted,
                button: Button(Strings.downloadAgain, action: .retry)
            )

        case .failed(.install, let release?):
            return UpdateStatusContent(
                tone: .amber, glyph: .exclamation, title: Strings.couldNotInstall(release.version.description),
                note: Strings.versionUnchanged,
                link: .download(release.pageURL),
                button: Button(Strings.tryAgain, action: .retry)
            )

        case .failed:
            let note = context.lastCheck.map { Strings.gitHubUnreachable(lastChecked: context.relative($0)) }
                ?? Strings.gitHubUnreachableNeverChecked
            return UpdateStatusContent(
                tone: .amber, glyph: .exclamation, title: Strings.couldNotCheck, note: note,
                button: Button(Strings.tryAgain, action: .check)
            )

        case .cannotInstall(let release):
            return UpdateStatusContent(
                tone: .blue, glyph: .arrowDown, title: Strings.updateAvailable(release.version.description),
                note: Strings.cannotReplaceItself,
                button: Button(Strings.download, isProminent: true, action: .open(release.pageURL))
            )
        }
    }

    /// The sentence before a What's new link ends in a middle dot, in both languages.
    private static func withSeparator(_ note: String) -> String {
        note + " ·"
    }

    private static func progress(received: Int64, total: Int64) -> Progress {
        let fraction = total > 0 ? min(1, max(0, Double(received) / Double(total))) : 0
        let text = "\(ByteCountFormatter.string(fromByteCount: received, countStyle: .file)) / "
            + ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return Progress(fraction: fraction, text: text)
    }
}

/// A release's notes, for the What's new popover.
struct WhatsNew: Equatable {
    let version: AppVersion
    let notes: String
    let pageURL: URL?

    init(version: AppVersion, notes: String, pageURL: URL?) {
        self.version = version
        self.notes = notes
        self.pageURL = pageURL
    }

    init(_ release: Release) {
        self.init(version: release.version, notes: release.notes, pageURL: release.pageURL)
    }

    /// One entry per line that starts with "- ", in Markdown, with the indented lines under it joined on.
    var items: [String] {
        var items: [String] = []
        for line in notes.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            if line.hasPrefix("- ") {
                items.append(String(text.dropFirst(2)))
            } else if line.first?.isWhitespace == true, let last = items.indices.last {
                items[last] += " " + text
            } else {
                items.append(text)
            }
        }
        return items
    }
}

extension Updater {
    /// The line under General in the Prism window's list while an update waits for the person.
    var attentionBadge: String? {
        guard needsAttention else { return nil }
        if case .ready = phase { return Strings.updateReadyBadge }
        return Strings.updateAvailableBadge
    }

    func statusContext(isWindowOpen: Bool) -> UpdateStatusContent.Context {
        UpdateStatusContent.Context(
            phase: phase,
            isAvailable: isAvailable,
            currentVersion: currentVersion,
            lastCheck: lastCheck,
            frequency: frequency,
            installsAutomatically: installsAutomatically,
            installsWhenDownloaded: installsWhenDownloaded,
            recentUpdate: recentUpdate,
            blockingTools: toolsBlockingRelaunch,
            isWindowOpen: isWindowOpen
        )
    }
}
