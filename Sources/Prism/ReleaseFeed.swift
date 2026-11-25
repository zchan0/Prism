import Foundation

/// A release's version, such as 0.3.1, compared number by number, so 0.10.0 comes after 0.9.0.
struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    let components: [Int]

    init(components: [Int]) {
        self.components = components
    }

    /// "0.3.1" or "v0.3.1"; nil for anything else.
    init?(_ text: String) {
        var text = Substring(text)
        if text.first == "v" {
            text = text.dropFirst()
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        var components: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part) else { return nil }
            components.append(number)
        }
        self.components = components
    }

    var description: String { components.map(String.init).joined(separator: ".") }

    /// 0.3 and 0.3.0 are the same version.
    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) == 0
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) < 0
    }

    private static func compare(_ lhs: AppVersion, _ rhs: AppVersion) -> Int {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }
}

/// The newest release on GitHub, as far as updating needs it.
struct Release: Equatable, Sendable {
    let version: AppVersion
    let archiveURL: URL
    let archiveSize: Int64
    /// Lowercase hex.
    let sha256: String
    /// What changed, without the install steps that follow it on the release page.
    let notes: String
    let pageURL: URL
}

protocol ReleaseFetching: Sendable {
    func latest() async throws -> Release
}

struct GitHubReleaseFeed: ReleaseFetching {
    static var endpoint: URL {
        #if DEBUG
        // A local fake release, so an update can be tried end to end without publishing one.
        if let feed = ProcessInfo.processInfo.environment["PRISM_UPDATE_FEED"].flatMap({ URL(string: $0) }) {
            return feed
        }
        #endif
        return URL(string: "https://api.github.com/repos/zchan0/Prism/releases/latest")!
    }

    func latest() async throws -> Release {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw UpdateError(.check, "GitHub answered \(status)")
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> Release {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw UpdateError(.check, "unreadable release: \(error)")
        }
        guard let version = AppVersion(payload.tagName) else {
            throw UpdateError(.check, "tag \(payload.tagName) is not a version")
        }
        let name = "Prism-\(version).zip"
        guard let asset = payload.assets.first(where: { $0.name == name }) else {
            throw UpdateError(.check, "the release has no \(name)")
        }
        guard let sha256 = asset.digest.flatMap(Self.sha256(fromDigest:)) else {
            throw UpdateError(.check, "\(name) has no SHA-256 digest")
        }
        return Release(
            version: version,
            archiveURL: asset.browserDownloadURL,
            archiveSize: asset.size,
            sha256: sha256,
            notes: Self.notes(from: payload.body ?? ""),
            pageURL: payload.htmlURL
        )
    }

    /// "sha256:<64 hex digits>", in either case.
    private static func sha256(fromDigest digest: String) -> String? {
        let prefix = "sha256:"
        guard digest.hasPrefix(prefix) else { return nil }
        let hex = digest.dropFirst(prefix.count).lowercased()
        guard hex.count == 64, hex.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        return hex
    }

    /// The release body up to its first second-level heading, where `scripts/dist.sh` starts the install steps.
    private static func notes(from body: String) -> String {
        let lines = body.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        let changes = lines.prefix { !$0.hasPrefix("## ") }
        return changes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Payload: Decodable {
        let tagName: String
        let htmlURL: URL
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }
    }

    private struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int64
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
            case digest
        }
    }
}
