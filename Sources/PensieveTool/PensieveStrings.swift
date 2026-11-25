import Foundation

enum PensieveStrings {
    static func itemCount(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No items")
        case 1: String(localized: "1 item")
        default: String(localized: "\(count) items")
        }
    }
    static let tagline = String(localized: "Press the shortcut in any app, pick something you copied, then paste it with ⌘V.")
    static let paused = String(localized: "Paused")
    static let recordingPaused = String(localized: "Recording is paused")
    static let resume = String(localized: "Resume")
    static let pauseRecording = String(localized: "Pause recording")
    static let shortcut = String(localized: "Shortcut")
    static let history = String(localized: "History")
    static let clearHistory = String(localized: "Clear history")
    static let clear = String(localized: "Clear…")
    static func confirmClear(_ count: Int) -> String {
        count == 1 ? String(localized: "Clear 1 item?") : String(localized: "Clear \(count) items?")
    }
    static let privateNote = String(localized: "Content that apps mark as private, such as passwords from a password manager, is not recorded.")
    static let search = String(localized: "Search")
    static let searchHistory = String(localized: "Search the clipboard history")
    static let nothingCopied = String(localized: "Nothing copied yet.")
    static let noMatches = String(localized: "No matches.")
    static let copy = String(localized: "Copy")
    static let copied = String(localized: "Copied")
    static let remove = String(localized: "Remove")
    static let color = String(localized: "Color")
    /// The sizes as plain digits: a number interpolated as a number gets a thousands separator, 1,280.
    static func image(width: Int, height: Int) -> String {
        let width = String(width)
        let height = String(height)
        return String(localized: "Image · \(width) × \(height)")
    }
    static func andMore(_ count: Int) -> String {
        String(localized: "and \(count) more")
    }
    static let keep = String(localized: "Keep")
    /// Its own key: the Chinese differs from `itemCount`'s, though the English is the same.
    static func keptItems(_ count: Int) -> String {
        String(localized: "pensieve.keep.items", defaultValue: "\(count) items")
    }
    static let clearAfter = String(localized: "Clear after")
    static func historyAge(_ age: HistoryAge) -> String {
        switch age {
        case .day: String(localized: "1 day")
        case .week: String(localized: "1 week")
        case .month: String(localized: "1 month")
        case .threeMonths: String(localized: "3 months")
        // Its own key: Lumos's "Never" reads differently in Chinese.
        case .never: String(localized: "pensieve.clearAfter.never", defaultValue: "Never")
        }
    }
    static func filter(_ filter: ClipFilter) -> String {
        switch filter {
        case .all: String(localized: "All")
        case .text: String(localized: "Text")
        case .links: String(localized: "Links")
        case .images: String(localized: "Images")
        case .files: String(localized: "Files")
        }
    }
    static let dontRecordFrom = String(localized: "Don't record from")
    static let ignoredAppsNote = String(localized: "Decided by the app in front when something is copied.")
    /// The sizes as plain digits, as in `image(width:height:)`.
    static func pixelSize(width: Int, height: Int) -> String {
        "\(String(width)) × \(String(height))"
    }
}
