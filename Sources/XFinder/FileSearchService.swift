import Foundation

struct FileSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let relativePath: String
    let kind: String
    let modificationDate: Date?
    let isDirectory: Bool
}

enum FileSearchService {
    static func search(
        in root: URL,
        query: String,
        includingHidden: Bool = false,
        limit: Int = 300
    ) async throws -> [FileSearchResult] {
        try await Task.detached(priority: .userInitiated) {
            try searchSync(in: root, query: query, includingHidden: includingHidden, limit: limit)
        }.value
    }

    static func searchSync(
        in root: URL,
        query: String,
        includingHidden: Bool = false,
        limit: Int = 300
    ) throws -> [FileSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let keys: [URLResourceKey] = [
            .contentModificationDateKey,
            .isDirectoryKey,
            .isHiddenKey,
            .isPackageKey,
            .localizedTypeDescriptionKey,
        ]
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !includingHidden {
            options.insert(.skipsHiddenFiles)
        }

        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: options
            )
        else { return [] }

        let basePath =
            root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path : root.standardizedFileURL.path + "/"
        var results: [FileSearchResult] = []
        for case let url as URL in enumerator {
            if Task.isCancelled { throw CancellationError() }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if !includingHidden, values.isHidden == true { continue }

            let relativePath =
                url.standardizedFileURL.path.hasPrefix(basePath)
                ? String(url.standardizedFileURL.path.dropFirst(basePath.count))
                : url.lastPathComponent
            guard
                url.lastPathComponent.localizedCaseInsensitiveContains(trimmed)
                    || relativePath.localizedCaseInsensitiveContains(trimmed)
            else { continue }

            let isDirectory = values.isDirectory == true
            results.append(
                FileSearchResult(
                    id: url.path,
                    url: url,
                    name: url.lastPathComponent,
                    relativePath: relativePath,
                    kind: values.localizedTypeDescription ?? (isDirectory ? "Folder" : "File"),
                    modificationDate: values.contentModificationDate,
                    isDirectory: isDirectory
                ))
            if results.count >= limit { break }
        }

        return results.sorted { lhs, rhs in
            let dateOrder = compareDates(lhs.modificationDate, rhs.modificationDate)
            if dateOrder != .orderedSame {
                return dateOrder == .orderedDescending
            }
            return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }

    private static func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (let lhs?, let rhs?):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedAscending
        case (_?, nil):
            return .orderedDescending
        }
    }
}
