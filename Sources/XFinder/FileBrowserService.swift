import AppKit
import Foundation

struct BrowserFileItem: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let modificationDate: Date?
    let size: Int64?
    let isDirectory: Bool
    let isPackage: Bool
    let typeDescription: String

    init(url: URL, resourceValues: URLResourceValues) {
        self.url = url
        name = url.lastPathComponent
        id = url.path
        modificationDate = resourceValues.contentModificationDate
        isDirectory = resourceValues.isDirectory == true
        isPackage = resourceValues.isPackage == true || url.pathExtension.lowercased() == "app"
        typeDescription = resourceValues.localizedTypeDescription ?? (isDirectory ? "Folder" : "File")

        if isDirectory {
            size = nil
        } else {
            size = Int64(resourceValues.fileSize ?? 0)
        }
    }
}

enum FileBrowserService {
    /// Async variant that reads the directory off the calling actor so large
    /// folders never block the main thread. Views must use this one; the sync
    /// version exists for tests and non-UI callers.
    static func contents(of url: URL, includingHidden: Bool = false) async throws -> [BrowserFileItem] {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let items = try contents(of: url, includingHidden: includingHidden)
            try Task.checkCancellation()
            return items
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func contents(of url: URL, includingHidden: Bool = false) throws -> [BrowserFileItem] {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isHiddenKey,
            .isPackageKey,
            .localizedTypeDescriptionKey,
        ]

        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )

        return urls.compactMap { itemURL in
            guard let values = try? itemURL.resourceValues(forKeys: keys) else { return nil }
            if !includingHidden, values.isHidden == true {
                return nil
            }
            return BrowserFileItem(url: itemURL, resourceValues: values)
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

extension BrowserFileItem {
    var canBrowseInline: Bool {
        canBrowseInline(showHiddenItems: false)
    }

    func canBrowseInline(showHiddenItems: Bool) -> Bool {
        isDirectory && (showHiddenItems || !isPackage)
    }
}
