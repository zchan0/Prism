import AppKit
import PrismKit
import SwiftUI

/// The About section of the General page: the updater's state, then its settings.
struct AboutSection: View {
    let updater: Updater
    /// Changes once a second, so "2 hours ago" keeps up.
    let revision: Int

    var body: some View {
        let _ = revision
        VStack(alignment: .leading, spacing: 6) {
            PanelSectionTitle(Strings.about)
            VStack(alignment: .leading, spacing: 8) {
                UpdateStatusCard(
                    content: .content(for: updater.statusContext(isWindowOpen: true)),
                    perform: perform
                )
                settingsCard
            }
        }
    }

    private var settingsCard: some View {
        PanelCard {
            PanelRow(Strings.checkForUpdates) {
                PanelPopUp(
                    selection: Binding(get: { updater.frequency }, set: { updater.setFrequency($0) }),
                    options: Updater.Frequency.allCases,
                    title: \.title
                )
                .accessibilityLabel(Strings.checkForUpdates)
            }
            PanelDivider.inCard
            PanelRow(
                Strings.installAutomatically,
                note: updater.installsAutomatically ? Strings.installAutomaticallyOn : Strings.installAutomaticallyOff
            ) {
                PanelSwitch(isOn: Binding(
                    get: { updater.installsAutomatically },
                    set: { updater.setInstallsAutomatically($0) }
                ))
                .accessibilityLabel(Strings.installAutomatically)
            }
        }
        .disabled(!updater.isAvailable)
    }

    private func perform(_ action: UpdateStatusContent.Action) {
        switch action {
        case .check: updater.check(userInitiated: true)
        case .update: updater.update()
        case .cancelDownload: updater.cancelDownload()
        case .installNow: updater.installNow()
        case .retry: updater.retry()
        case .open(let url): NSWorkspace.shared.open(url)
        }
    }
}

/// The line at the bottom of the General page.
struct AboutFooter: View {
    static let repository = URL(string: "https://github.com/zchan0/Prism")!
    static let releases = URL(string: "https://github.com/zchan0/Prism/releases")!

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "© 2026 zchan0")
            Text(verbatim: "·").accessibilityHidden(true)
            NoteLink(title: "GitHub") { NSWorkspace.shared.open(Self.repository) }
            Text(verbatim: "·").accessibilityHidden(true)
            NoteLink(title: Strings.releaseNotes) { NSWorkspace.shared.open(Self.releases) }
        }
        .font(PanelFont.note)
        .foregroundStyle(Color(nsColor: Palette.ink3))
        .padding(.horizontal, 8)
    }
}

struct UpdateStatusCard: View {
    let content: UpdateStatusContent
    let perform: @MainActor (UpdateStatusContent.Action) -> Void

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    UpdateTile(tone: content.tone, glyph: content.glyph)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(PanelFont.name)
                            .foregroundStyle(Color(nsColor: Palette.ink))
                            .fixedSize(horizontal: false, vertical: true)
                        NoteWithLink(note: content.note, link: content.link, open: { perform(.open($0)) })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let button = content.button {
                        PanelButton(button.title, style: button.isProminent ? .prominent : .regular) {
                            perform(button.action)
                        }
                        .disabled(!button.isEnabled)
                    }
                }
                .frame(minHeight: 30)
                if let progress = content.progress {
                    HStack(spacing: 10) {
                        LevelBar(fraction: progress.fraction, color: Palette.accent)
                        Text(progress.text)
                            .font(PanelFont.note)
                            .monospacedDigit()
                            .foregroundStyle(Color(nsColor: Palette.ink3))
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: 86, alignment: .trailing)
                    }
                    .padding(.leading, 40)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(12)
        }
    }
}

private struct UpdateTile: View {
    let tone: UpdateStatusContent.Tone
    let glyph: UpdateStatusContent.Glyph

    var body: some View {
        let tint = tone.tint
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: tint.fill))
            if let symbol = glyph.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(nsColor: tint.glyph))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// The card's note, and the link after it on the same line, or on the next when they do not fit on one.
private struct NoteWithLink: View {
    let note: String
    let link: UpdateStatusContent.Link?
    let open: @MainActor (URL) -> Void

    var body: some View {
        if let link {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 3) {
                    text.fixedSize()
                    linkView(link)
                }
                VStack(alignment: .leading, spacing: 2) {
                    text.fixedSize(horizontal: false, vertical: true)
                    linkView(link)
                }
            }
        } else {
            text.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var text: some View {
        Text(note)
            .font(PanelFont.note)
            .foregroundStyle(Color(nsColor: Palette.ink3))
    }

    @ViewBuilder
    private func linkView(_ link: UpdateStatusContent.Link) -> some View {
        switch link {
        case .whatsNew(let whatsNew):
            WhatsNewLink(whatsNew: whatsNew, open: open)
        case .download(let url):
            NoteLink(title: link.title) { open(url) }
        }
    }
}

/// Text in the accent color that does something when clicked, and that the keyboard and VoiceOver reach as a link.
private struct NoteLink: View {
    let title: String
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PanelFont.note)
                .foregroundStyle(Color(nsColor: Palette.accentInk))
                .underline(hovered)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isLink)
    }
}

/// What's new: the release's notes in a popover under the link, or its page when there are no notes.
private struct WhatsNewLink: View {
    let whatsNew: WhatsNew
    let open: @MainActor (URL) -> Void
    @State private var isShown = false

    var body: some View {
        NoteLink(title: Strings.whatsNew) {
            if whatsNew.items.isEmpty {
                if let page = whatsNew.pageURL { open(page) }
            } else {
                isShown = true
            }
        }
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            WhatsNewView(whatsNew: whatsNew) { url in
                isShown = false
                open(url)
            }
        }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.environment["PRISM_SHOW_WHATS_NEW"] == "1" else { return }
            // A popover opens only from a view in a window on screen, which a screenshot run puts there after this.
            try? await Task.sleep(for: .seconds(0.6))
            isShown = !whatsNew.items.isEmpty
        }
        #endif
    }
}

private struct WhatsNewView: View {
    static let maxListHeight: CGFloat = 300

    let whatsNew: WhatsNew
    let open: @MainActor (URL) -> Void
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "\(Strings.appName) \(whatsNew.version)")
                .font(PanelFont.name)
                .foregroundStyle(Color(nsColor: Palette.ink))
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                list.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .frame(height: min(max(listHeight, 1), Self.maxListHeight))
            if let page = whatsNew.pageURL {
                PanelDivider()
                NoteLink(title: Strings.viewOnGitHub) { open(page) }
            }
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(whatsNew.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "•")
                        .accessibilityHidden(true)
                    Text(Self.styled(item))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color(nsColor: Palette.ink2))
        .lineSpacing(2)
    }

    private static func styled(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

private extension UpdateStatusContent.Tone {
    var tint: ToolTint {
        switch self {
        case .green: Palette.vitals
        case .blue: Palette.portkey
        case .amber: Palette.lumos
        case .neutral: Palette.neutral
        }
    }
}

private extension UpdateStatusContent.Glyph {
    /// Nil for the spinner, which is a progress view.
    var symbol: String? {
        switch self {
        case .checkmark: "checkmark"
        case .arrowDown: "arrow.down"
        case .exclamation: "exclamationmark"
        case .dash: "minus"
        case .spinner: nil
        }
    }
}

extension Updater.Frequency {
    var title: String {
        switch self {
        case .daily: Strings.daily
        case .weekly: Strings.weekly
        case .monthly: Strings.monthly
        case .never: Strings.never
        }
    }
}
