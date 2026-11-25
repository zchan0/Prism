import AppKit
import PrismKit
import SwiftUI

private enum Metrics {
    static let panelRowHeight: CGFloat = 36
    static let windowWidth: CGFloat = 480
    static let searchHeight: CGFloat = 52
    static let windowRowHeight: CGFloat = 40
    static let windowRowGap: CGFloat = 2
    static let visibleWindowRows = 8
    static let listPadding: CGFloat = 6
    static let leadingSlot: CGFloat = 22
    static let copiedFor: Duration = .seconds(0.35)
    static let previewHoverDelay: Duration = .milliseconds(400)
    static let settingsSpacing: CGFloat = 16
}

/// The body of the panel: the way into the history window, then the items. A click on an item copies it, says so,
/// and closes the panel.
struct PensievePanelView: View {
    let tool: PensieveTool
    @Environment(\.toolPanel) private var panel
    @State private var copiedID: UUID?
    /// The order while "Copied" shows: copying moves the item to the top, and the row should stay where it was clicked.
    @State private var frozenItems: [ClipItem]?
    @State private var window = WindowBox()

    var body: some View {
        let items = frozenItems ?? tool.panelItems
        PanelCard {
            if tool.isPaused {
                PanelRow(PensieveStrings.recordingPaused) {
                    PanelButton(PensieveStrings.resume) {
                        tool.setPaused(false)
                    }
                }
                PanelDivider.inCard
            }
            SearchRow(shortcut: tool.shortcut) {
                panel.close()
                tool.showHistory()
            }
            if items.isEmpty {
                PanelDivider.inCard
                Text(PensieveStrings.nothingCopied)
                    .font(PanelFont.note)
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: Metrics.panelRowHeight, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        PanelClipRow(item: item, tool: tool, window: window, isCopied: copiedID == item.id) {
                            copy(item, shown: items)
                        }
                    }
                }
            }
        }
        .background(WindowReader(box: window))
        .onDisappear { tool.hidePreview() }
    }

    private func copy(_ item: ClipItem, shown items: [ClipItem]) {
        guard copiedID == nil else { return }
        tool.hidePreview()
        frozenItems = items
        guard tool.copyToPasteboard(item.id) else {
            frozenItems = nil
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            copiedID = item.id
        }
        Task {
            try? await Task.sleep(for: Metrics.copiedFor)
            panel.close()
        }
    }
}

private struct SearchRow: View {
    let shortcut: Shortcut?
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                    .frame(width: Metrics.leadingSlot, height: Metrics.leadingSlot)
                Text(PensieveStrings.search)
                    .font(PanelFont.title)
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                Spacer(minLength: 8)
                if let shortcut {
                    ShortcutKeys(shortcut)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: PanelRowMetrics.minHeight)
            .background(hovered ? Color(nsColor: Palette.hover) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(PensieveStrings.searchHistory)
    }
}

private struct PanelClipRow: View {
    let item: ClipItem
    let tool: PensieveTool
    let window: WindowBox
    let isCopied: Bool
    let action: @MainActor () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ClipRow(item: item, tool: tool) {
                if isCopied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(PensieveStrings.copied)
                            .font(PanelFont.section)
                    }
                    .foregroundStyle(Color(nsColor: Palette.accentInk))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Metrics.panelRowHeight)
            .background(hovered ? Color(nsColor: Palette.hover) : .clear)
            .overlay(alignment: .top) { PanelDivider.inCard }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hovered = isHovered
            guard item.kind == .image else { return }
            if isHovered, let window = window.window {
                tool.showPreview(of: item, beside: window, preferring: .left, after: Metrics.previewHoverDelay)
            } else {
                tool.hidePreview(of: item.id)
            }
        }
    }
}

/// The window a view is in, for what goes beside it.
@MainActor
final class WindowBox {
    weak var window: NSWindow?
}

private struct WindowReader: NSViewRepresentable {
    let box: WindowBox

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.box = box
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.box = box
        box.window = view.window
    }

    final class ReaderView: NSView {
        var box: WindowBox?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            box?.window = window
        }
    }
}

/// A picture as large as the preview allows, and its size in pixels under it.
struct ImagePreview: View {
    let image: NSImage
    let size: CGSize
    let pixelWidth: Int
    let pixelHeight: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(verbatim: PensieveStrings.pixelSize(width: pixelWidth, height: pixelHeight))
                .font(PanelFont.note)
                .monospacedDigit()
                .foregroundStyle(Color(nsColor: Palette.ink3))
        }
        .padding(12)
        .fixedSize()
    }
}

/// The shortcut, how much to keep, the pause switch and the way to clear the history, then the apps whose copies are
/// left out, on the tool's page in the Prism window.
struct PensieveSettingsView: View {
    let tool: PensieveTool
    let recorder: HistoryShortcutRecorder
    @State private var confirmsClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.settingsSpacing) {
            history
            IgnoredAppsSection(tool: tool)
        }
    }

    private var history: some View {
        PanelSection(PensieveStrings.history, note: PensieveStrings.privateNote) {
            VStack(alignment: .leading, spacing: 0) {
                PanelRow(PensieveStrings.shortcut) {
                    ShortcutButton(
                        name: PensieveStrings.shortcut,
                        shortcut: tool.shortcut,
                        isRecording: recorder.recordingSlot == .history,
                        start: { recorder.start(for: .history) }
                    )
                }
                if let message {
                    Text(message)
                        .font(PanelFont.note)
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 9)
                }
            }
            .contentShape(Rectangle())
            .contextMenu {
                if tool.shortcut != nil {
                    Button(Strings.clearShortcut) {
                        recorder.clear(.history)
                    }
                }
            }
            PanelDivider.inCard
            PanelRow(PensieveStrings.keep) {
                PanelPopUp(
                    selection: Binding(get: { tool.itemLimit }, set: { tool.setItemLimit($0) }),
                    options: PensieveTool.itemLimits,
                    title: PensieveStrings.keptItems
                )
            }
            PanelDivider.inCard
            PanelRow(PensieveStrings.clearAfter) {
                PanelPopUp(
                    selection: Binding(get: { tool.historyAge }, set: { tool.setHistoryAge($0) }),
                    options: HistoryAge.allCases,
                    title: PensieveStrings.historyAge
                )
            }
            PanelDivider.inCard
            PanelRow(PensieveStrings.pauseRecording) {
                PanelSwitch(isOn: Binding(
                    get: { tool.isPaused },
                    set: { tool.setPaused($0) }
                ))
                .accessibilityLabel(PensieveStrings.pauseRecording)
            }
            PanelDivider.inCard
            PanelRow(PensieveStrings.clearHistory) {
                HStack(spacing: 10) {
                    Text(PensieveStrings.itemCount(tool.items.count))
                        .font(PanelFont.note)
                        .monospacedDigit()
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                    PanelButton(confirmsClear ? PensieveStrings.confirmClear(tool.items.count) : PensieveStrings.clear) {
                        if confirmsClear {
                            confirmsClear = false
                            tool.clear()
                        } else {
                            confirmsClear = true
                        }
                    }
                    .disabled(tool.items.isEmpty)
                }
            }
        }
        .onChange(of: confirmsClear) { _, confirms in
            guard confirms else { return }
            Task {
                try? await Task.sleep(for: .seconds(4))
                confirmsClear = false
            }
        }
    }

    private var message: String? {
        if let notice = recorder.notice {
            switch notice.refusal {
            case .needsModifier: return Strings.shortcutNeedsModifier
            case .refusedBySystem: return Strings.shortcutCouldNotBeSetUp
            }
        }
        return tool.shortcutFailed ? Strings.shortcutCouldNotBeSetUp : nil
    }
}

/// The apps whose copies are not recorded, on the tool's page in the Prism window.
private struct IgnoredAppsSection: View {
    let tool: PensieveTool

    var body: some View {
        let apps = tool.ignoredApps
        PanelSection(PensieveStrings.dontRecordFrom, note: PensieveStrings.ignoredAppsNote) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                if index > 0 {
                    PanelDivider.inCard
                }
                AppListRow(name: tool.catalog.displayName(of: app), icon: tool.catalog.icon(atPath: app.path)) {
                    tool.stopIgnoring(app)
                }
            }
            if !apps.isEmpty {
                PanelDivider.inCard
            }
            AppAddMenu(catalog: tool.catalog, isListed: tool.isIgnored) { app in
                tool.ignore(app)
            }
        }
    }
}

/// The history window: the search field, the items, and the keys it answers to.
struct HistoryView: View {
    @Bindable var browser: HistoryBrowser
    let tool: PensieveTool
    let choose: @MainActor (UUID) -> Void
    let selectionChanged: @MainActor (ClipItem?) -> Void
    let searchFieldCreated: @MainActor (NSTextField) -> Void

    var body: some View {
        let results = browser.results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(nsColor: Palette.ink3))
                SearchField(text: $browser.query, prompt: PensieveStrings.search, created: searchFieldCreated)
                    .accessibilityLabel(PensieveStrings.searchHistory)
                PanelMenuButton(
                    selection: browser.filter,
                    options: ClipFilter.allCases,
                    title: PensieveStrings.filter
                ) { filter in
                    browser.filter = filter
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Metrics.searchHeight)
            PanelDivider()
            if results.isEmpty {
                Text(browser.hasHistory ? PensieveStrings.noMatches : PensieveStrings.nothingCopied)
                    .font(PanelFont.title)
                    .foregroundStyle(Color(nsColor: Palette.ink2))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                list(results)
            }
            PanelDivider()
            footer
        }
        .frame(width: Metrics.windowWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: browser.selection) { _, selection in
            selectionChanged(selection)
        }
    }

    private func list(_ results: [ClipItem]) -> some View {
        let selectedID = browser.selection?.id
        let shownRows = CGFloat(min(results.count, Metrics.visibleWindowRows))
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metrics.windowRowGap) {
                    ForEach(results) { item in
                        Button {
                            choose(item.id)
                        } label: {
                            WindowClipRow(item: item, tool: tool, isSelected: item.id == selectedID)
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                    }
                }
                .padding(Metrics.listPadding)
            }
            .frame(height: shownRows * Metrics.windowRowHeight + (shownRows - 1) * Metrics.windowRowGap + 2 * Metrics.listPadding)
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
            .onChange(of: browser.opening) {
                guard let first = results.first?.id else { return }
                proxy.scrollTo(first, anchor: .top)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(verbatim: tool.title)
                    .font(PanelFont.section)
            }
            .foregroundStyle(Color(nsColor: Palette.ink3))
            Spacer(minLength: 0)
            KeyHint(keys: ["↩"], label: PensieveStrings.copy)
            KeyHint(keys: ["⌘", "⌫"], label: PensieveStrings.remove)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
    }
}

private struct KeyHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            ShortcutKeys(keys: keys)
            Text(label)
                .font(PanelFont.note)
                .foregroundStyle(Color(nsColor: Palette.ink3))
        }
    }
}

/// Without a hover tint: the keyboard moves the selection here, and in this window SwiftUI reports a row under no
/// pointer as hovered when the window opens.
private struct WindowClipRow: View {
    let item: ClipItem
    let tool: PensieveTool
    let isSelected: Bool

    var body: some View {
        ClipRow(item: item, tool: tool) {
            if isSelected {
                Keycap(key: "↩")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Metrics.windowRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color(nsColor: Palette.selection) : .clear)
        )
        .contentShape(Rectangle())
    }
}

/// One item on one line, the same in the panel and in the history window: its kind's symbol, a thumbnail, a file's
/// icon or a color's swatch, then its text, then `trailing`.
struct ClipRow<Trailing: View>: View {
    let item: ClipItem
    let tool: PensieveTool
    @ViewBuilder let trailing: Trailing
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            leading
                .frame(width: Metrics.leadingSlot, height: Metrics.leadingSlot)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .task(id: item.id) {
            guard item.kind == .image, thumbnail == nil else { return }
            thumbnail = await tool.thumbnail(of: item)
        }
    }

    private var ink: Color { Color(nsColor: Palette.ink) }
    private var ink3: Color { Color(nsColor: Palette.ink3) }

    @ViewBuilder private var leading: some View {
        switch item.kind {
        case .text:
            Image(systemName: item.isLink ? "link" : "text.alignleft")
                .font(.system(size: 13))
                .foregroundStyle(ink3)
        case .image:
            if let image = thumbnail ?? tool.cachedThumbnail(of: item.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Metrics.leadingSlot, height: Metrics.leadingSlot)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 13))
                    .foregroundStyle(ink3)
            }
        case .file:
            if let path = item.filePaths?.first {
                Image(nsImage: tool.icon(forFile: path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Metrics.leadingSlot, height: Metrics.leadingSlot)
            }
        case .color:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(swatch)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                )
                .frame(width: 17, height: 17)
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            line(preview)
        case .image:
            line(PensieveStrings.image(width: item.pixelWidth ?? 0, height: item.pixelHeight ?? 0))
                .monospacedDigit()
        case .file:
            let names = item.fileNames
            HStack(spacing: 4) {
                Text(verbatim: names.first ?? "")
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if names.count > 1 {
                    Text(PensieveStrings.andMore(names.count - 1))
                        .foregroundStyle(ink3)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .font(PanelFont.title)
        case .color:
            line(item.colorValue ?? PensieveStrings.color, font: PanelFont.title.monospaced())
        }
    }

    private func line(_ text: String, font: Font = PanelFont.title) -> some View {
        Text(verbatim: text)
            .font(font)
            .foregroundStyle(ink)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// The text on one line: its lines run together, and only the start is laid out.
    private var preview: String {
        (item.text ?? "").prefix(300)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var swatch: Color {
        let rgba = item.rgba ?? [0.5, 0.5, 0.5, 1]
        guard rgba.count == 4 else { return .gray }
        return Color(.sRGB, red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
    }
}
