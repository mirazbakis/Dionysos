import Foundation

/// IPAs the user imported, kept in Application Support so apps can be
/// re-signed and refreshed later without picking the file again.
enum IPAStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("IPAs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies a picked IPA into the store (security-scoped) and returns the copy.
    static func importIPA(from url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    struct Item: Identifiable, Hashable {
        let url: URL
        let size: Int64
        let modified: Date
        var id: URL { url }
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    static func list() -> [Item] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return Item(url: url, size: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.modified > $1.modified }
    }

    static func delete(_ item: Item) {
        try? FileManager.default.removeItem(at: item.url)
    }
}
