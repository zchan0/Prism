import Foundation
import ImageIO
import os

/// The history on disk: `index.json` lists the items, newest first, and each item's representations are in
/// `<id>.plist` next to it. Searching and listing read only the index.
///
/// Every file operation runs in order on one background queue, so a large image never holds up the main thread and
/// a write never overtakes the one before it. Reads that must see the latest writes wait for the queue.
final class HistoryStore: Sendable {
    private struct Index: Codable {
        var version = 1
        var items: [ClipItem]
    }

    let directory: URL
    private let queue = DispatchQueue(label: "io.github.zchan0.prism.pensieve.store", qos: .utility)
    private static let logger = Logger(subsystem: "io.github.zchan0.prism", category: "Pensieve")

    init(directory: URL) {
        self.directory = directory
    }

    private var indexURL: URL { directory.appending(path: "index.json") }

    private func dataURL(_ id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).plist")
    }

    /// The saved items, or none when the index is missing or unreadable. Data files the index does not list are
    /// left over from a crash and deleted.
    func load() -> [ClipItem] {
        queue.sync {
            let items = (try? Data(contentsOf: indexURL))
                .flatMap { try? JSONDecoder().decode(Index.self, from: $0) }?.items ?? []
            removeDataFiles(except: Set(items.map(\.id)))
            return items
        }
    }

    /// Writes the new item's data, deletes the data of `removed`, and saves `items` as the index, in that order.
    func save(_ items: [ClipItem], adding new: (id: UUID, payload: Payload)? = nil, removing removed: [UUID] = []) {
        queue.async { [self] in
            guard prepareDirectory() else { return }
            if let new {
                write(new.payload, to: dataURL(new.id))
            }
            writeIndex(items)
            for id in removed {
                try? FileManager.default.removeItem(at: dataURL(id))
            }
        }
    }

    func removeAll() {
        queue.async { [self] in
            guard FileManager.default.fileExists(atPath: directory.path) else { return }
            writeIndex([])
            removeDataFiles(except: [])
        }
    }

    /// Waits for the writes before it, so an item copied a moment ago can be read back.
    func payload(of id: UUID) -> Payload? {
        queue.sync { readPayload(dataURL(id)) }
    }

    /// Calls `completion` on the store's queue.
    func thumbnail(of id: UUID, maxPixelSize: Int, completion: @escaping @Sendable (CGImage?) -> Void) {
        queue.async { [self] in
            let image = readPayload(dataURL(id)).flatMap { Self.imageData(in: $0) }
                .flatMap { Self.thumbnail(of: $0, maxPixelSize: maxPixelSize) }
            completion(image)
        }
    }

    func waitUntilSaved() {
        queue.sync {}
    }

    static func imageData(in payload: Payload) -> Data? {
        let representations = payload.flatMap { $0 }
        return (representations.first { $0.type == "public.png" } ?? representations.first { $0.type == "public.tiff" })?.data
    }

    static func thumbnail(of data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // The history is the person's clipboard, so only they may open the folder. The files are not encrypted.
    private func prepareDirectory() -> Bool {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            return true
        } catch {
            Self.logger.error("Preparing \(self.directory.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func writeIndex(_ items: [ClipItem]) {
        do {
            try JSONEncoder().encode(Index(items: items)).write(to: indexURL, options: .atomic)
        } catch {
            Self.logger.error("Saving the index failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func write(_ payload: Payload, to url: URL) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            try encoder.encode(payload).write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Saving an item failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func readPayload(_ url: URL) -> Payload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListDecoder().decode(Payload.self, from: data)
    }

    private func removeDataFiles(except kept: Set<UUID>) {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasSuffix(".plist") {
            guard let id = UUID(uuidString: String(name.dropLast(6))), !kept.contains(id) else { continue }
            try? manager.removeItem(at: directory.appending(path: name))
        }
    }
}
