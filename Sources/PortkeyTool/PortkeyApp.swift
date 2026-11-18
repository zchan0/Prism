import Foundation

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

/// An app that can be added: one that is open, one in the Dock, or one the person picked in Applications.
struct AppCandidate: Identifiable, Equatable, Sendable {
    let bundleID: String
    let path: String
    let name: String

    var id: String { path }

    /// The apps kept in the Dock, from the Dock's `persistent-apps` preference, in Dock order. An entry without a
    /// bundle id, or whose app is no longer where the Dock says, is left out.
    static func dockApps(persistentApps: [Any], fileExists: (String) -> Bool) -> [AppCandidate] {
        var seenPaths = Set<String>()
        return persistentApps.compactMap { entry -> AppCandidate? in
            guard let tile = (entry as? [String: Any])?["tile-data"] as? [String: Any],
                  let bundleID = tile["bundle-identifier"] as? String, !bundleID.isEmpty,
                  let urlString = (tile["file-data"] as? [String: Any])?["_CFURLString"] as? String,
                  let path = filePath(urlString), fileExists(path),
                  seenPaths.insert(path).inserted else { return nil }
            let label = tile["file-label"] as? String ?? ""
            return AppCandidate(bundleID: bundleID, path: path, name: label.isEmpty ? appName(atPath: path) : label)
        }
    }

    private static func filePath(_ urlString: String) -> String? {
        if urlString.hasPrefix("/") { return URL(fileURLWithPath: urlString).path }
        guard let url = URL(string: urlString), url.isFileURL else { return nil }
        return url.path
    }

    private static func appName(atPath path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
