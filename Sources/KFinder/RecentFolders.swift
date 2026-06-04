import Foundation

/// Most-recently-used list of folder paths, kept as a pure value transform so
/// the ordering/dedup/cap rules can be unit tested without a live store.
enum RecentFolders {
    static let limit = 12

    /// Returns `list` with `path` promoted to the front: existing entries are
    /// de-duplicated, empty paths are ignored, and the result is capped at
    /// `limit` (newest first).
    static func updated(_ list: [String], adding path: String, limit: Int = limit) -> [String] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return list }

        var result = list.filter { $0 != trimmed }
        result.insert(trimmed, at: 0)
        if result.count > limit {
            result = Array(result.prefix(limit))
        }
        return result
    }
}
