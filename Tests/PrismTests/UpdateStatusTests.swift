import Foundation
import Testing
@testable import Prism

@MainActor
struct UpdateStatusTests {
    private typealias Button = UpdateStatusContent.Button

    private let current = AppVersion("0.3.0")!
    private let page = URL(string: "https://github.com/zchan0/Prism/releases/tag/v0.3.1")!
    private let checked = Date(timeIntervalSince1970: 1_800_000_000)

    private var release: Release {
        Release(
            version: AppVersion("0.3.1")!,
            archiveURL: URL(string: "https://github.com/zchan0/Prism/releases/download/v0.3.1/Prism-0.3.1.zip")!,
            archiveSize: 3_600_000,
            sha256: String(repeating: "a", count: 64),
            notes: "- One.\n- Two.",
            pageURL: page
        )
    }

    private func content(
        _ phase: Updater.Phase,
        _ change: (inout UpdateStatusContent.Context) -> Void = { _ in }
    ) -> UpdateStatusContent {
        var context = UpdateStatusContent.Context(
            phase: phase,
            isAvailable: true,
            currentVersion: current,
            lastCheck: checked,
            frequency: .daily,
            installsAutomatically: true,
            installsWhenDownloaded: false,
            recentUpdate: nil,
            blockingTools: [],
            isWindowOpen: true,
            relative: { _ in "2 hours ago" }
        )
        change(&context)
        return .content(for: context)
    }

    // MARK: Up to date

    @Test func upToDate() {
        let card = content(.idle)
        #expect(card.tone == .green)
        #expect(card.glyph == .checkmark)
        #expect(card.title == "Prism 0.3.0")
        #expect(card.note == "Up to date · Last checked 2 hours ago")
        #expect(card.link == nil)
        #expect(card.button == Button("Check Now", action: .check))
    }

    @Test func automaticChecksOff() {
        let card = content(.idle) { $0.frequency = .never }
        #expect(card.title == "Prism 0.3.0")
        #expect(card.note == "Automatic checks are off · Last checked 2 hours ago")
        #expect(card.button == Button("Check Now", action: .check))
    }

    @Test func neverChecked() {
        let card = content(.idle) { $0.lastCheck = nil }
        #expect(card.tone == .green)
        #expect(card.title == "Prism 0.3.0")
        #expect(card.note == "Not checked yet")
        #expect(card.button == Button("Check Now", action: .check))
    }

    @Test func justUpdated() {
        let recent = Updater.RecentUpdate(version: current, date: checked, notes: "- Fixed.", pageURL: page)
        let card = content(.idle) { $0.recentUpdate = recent }
        #expect(card.tone == .green)
        #expect(card.glyph == .checkmark)
        #expect(card.title == "Prism 0.3.0")
        #expect(card.note == "Updated 2 hours ago ·")
        #expect(card.link == .whatsNew(WhatsNew(version: current, notes: "- Fixed.", pageURL: page)))
        #expect(card.button == Button("Check Now", action: .check))
    }

    // MARK: Checking and a new version

    @Test func checking() {
        let card = content(.checking)
        #expect(card.tone == .neutral)
        #expect(card.glyph == .spinner)
        #expect(card.title == "Checking for updates…")
        #expect(card.note == "You have 0.3.0")
        #expect(card.button == nil)
    }

    @Test func available() {
        let card = content(.available(release))
        #expect(card.tone == .blue)
        #expect(card.glyph == .arrowDown)
        #expect(card.title == "Prism 0.3.1 is available")
        #expect(card.note == "You have 0.3.0 ·")
        #expect(card.link == .whatsNew(WhatsNew(release)))
        #expect(card.button == Button("Update", isProminent: true, action: .update))
    }

    @Test func downloading() {
        let received = release.archiveSize * 39 / 100
        let automatic = content(.downloading(release, received: received))
        #expect(automatic.tone == .blue)
        #expect(automatic.glyph == .arrowDown)
        #expect(automatic.title == "Downloading Prism 0.3.1")
        #expect(automatic.note == "Installs when Prism is idle")
        #expect(automatic.button == Button("Cancel", action: .cancelDownload))
        let size = { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        #expect(automatic.progress == UpdateStatusContent.Progress(fraction: 0.39, text: "\(size(received)) / \(size(3_600_000))"))

        let byHand = content(.downloading(release, received: received)) { $0.installsWhenDownloaded = true }
        #expect(byHand.note == "Installs and reopens Prism when the download finishes")
    }

    @Test func readyWhileTheWindowIsOpen() {
        let card = content(.ready(release))
        #expect(card.tone == .blue)
        #expect(card.glyph == .arrowDown)
        #expect(card.title == "Prism 0.3.1 is ready")
        #expect(card.note == "Installs when you close this window ·")
        #expect(card.link == .whatsNew(WhatsNew(release)))
        #expect(card.button == Button("Install and Relaunch", isProminent: true, action: .installNow))
        #expect(content(.ready(release)) { $0.isWindowOpen = false }.note == "Installs when Prism is idle ·")
    }

    @Test func readyWhileAToolIsBusy() {
        let card = content(.ready(release)) { $0.blockingTools = ["Lumos"] }
        #expect(card.title == "Prism 0.3.1 is ready")
        #expect(card.note == "Installs when Lumos finishes ·")
        #expect(card.button == Button("Install and Relaunch", isProminent: true, action: .installNow))
        #expect(card.button?.isEnabled == true)
    }

    @Test func readyWithoutInstallingAutomatically() {
        let card = content(.ready(release)) { $0.installsAutomatically = false }
        #expect(card.title == "Prism 0.3.1 is ready")
        #expect(card.note == "Downloaded and ready to install ·")
        #expect(card.button == Button("Install and Relaunch", isProminent: true, action: .installNow))

        let busy = content(.ready(release)) {
            $0.installsAutomatically = false
            $0.blockingTools = ["Lumos"]
        }
        #expect(busy.note == "Downloaded and ready to install ·")
        #expect(busy.button?.isEnabled == true)
    }

    @Test func installing() {
        let card = content(.installing(release))
        #expect(card.tone == .blue)
        #expect(card.glyph == .spinner)
        #expect(card.title == "Installing Prism 0.3.1…")
        #expect(card.note == "Prism will reopen")
        #expect(card.button == nil)
        #expect(content(.installing(release)) { $0.blockingTools = ["Lumos"] }.note == "Prism will reopen. Lumos keeps running.")
    }

    // MARK: Failures

    @Test func checkFailed() {
        let card = content(.failed(.check, nil))
        #expect(card.tone == .amber)
        #expect(card.glyph == .exclamation)
        #expect(card.title == "Couldn't check for updates")
        #expect(card.note == "GitHub can't be reached. Last checked 2 hours ago")
        #expect(card.button == Button("Try Again", action: .check))
        #expect(content(.failed(.check, nil)) { $0.lastCheck = nil }.note == "GitHub can't be reached.")
    }

    @Test func downloadFailed() {
        let card = content(.failed(.download, release))
        #expect(card.tone == .amber)
        #expect(card.glyph == .exclamation)
        #expect(card.title == "Couldn't download Prism 0.3.1")
        #expect(card.note == "The download stopped. You can also")
        #expect(card.link == .download(page))
        #expect(card.link?.title == "download it from GitHub")
        #expect(card.button == Button("Try Again", action: .retry))
    }

    @Test func verificationFailed() {
        let card = content(.failed(.verification, release))
        #expect(card.tone == .amber)
        #expect(card.title == "Prism 0.3.1 didn't pass verification")
        #expect(card.note == "The download was deleted. Your current version is unchanged.")
        #expect(card.link == nil)
        #expect(card.button == Button("Download Again", action: .retry))
    }

    @Test func installFailed() {
        let card = content(.failed(.install, release))
        #expect(card.tone == .amber)
        #expect(card.title == "Couldn't install Prism 0.3.1")
        #expect(card.note == "Your current version is unchanged. You can also")
        #expect(card.link == .download(page))
        #expect(card.button == Button("Try Again", action: .retry))
    }

    @Test func cannotInstall() {
        let card = content(.cannotInstall(release))
        #expect(card.tone == .blue)
        #expect(card.glyph == .arrowDown)
        #expect(card.title == "Prism 0.3.1 is available")
        #expect(card.note == "Prism can't replace itself here. Move it to the Applications folder with Finder, or download the new version.")
        #expect(card.button == Button("Download", isProminent: true, action: .open(page)))
    }

    @Test func aDevelopmentBuild() {
        for phase in [Updater.Phase.idle, .available(release)] {
            let card = content(phase) { $0.isAvailable = false }
            #expect(card.tone == .neutral)
            #expect(card.glyph == .dash)
            #expect(card.title == "Prism dev")
            #expect(card.note == "Development builds don't check for updates")
            #expect(card.button == nil)
        }
    }

    // MARK: What's new

    @Test func whatsNewHasOneItemPerDashLine() {
        let notes = """
        - Pensieve, a new tool.
          It keeps what you copied.
        - *Appearance* on *General*.

        - A [link](https://example.com).
        """
        let items = WhatsNew(version: current, notes: notes, pageURL: nil).items
        #expect(items == [
            "Pensieve, a new tool. It keeps what you copied.",
            "*Appearance* on *General*.",
            "A [link](https://example.com).",
        ])
        #expect(WhatsNew(version: current, notes: "", pageURL: nil).items.isEmpty)
    }
}
