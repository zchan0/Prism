import Foundation
import PrismKit

/// One app the person added, with its shortcut. Stored as JSON, so renaming a property loses the person's list.
struct PortkeyApp: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let bundleID: String
    /// Where the app was when it was added, which tells apart two copies with one bundle id.
    let path: String
    /// The name when it was added, shown when the app is no longer at `path`.
    let name: String
    var shortcut: Shortcut?

    var target: AppSwitcher.Target {
        AppSwitcher.Target(bundleID: bundleID, savedURL: URL(fileURLWithPath: path))
    }

    func isSameApp(as candidate: AppCandidate) -> Bool {
        bundleID == candidate.bundleID && path == candidate.path
    }

    static func decodeList(_ json: String) -> [PortkeyApp] {
        (try? JSONDecoder().decode([PortkeyApp].self, from: Data(json.utf8))) ?? []
    }

    static func encodeList(_ apps: [PortkeyApp]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(apps) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}
