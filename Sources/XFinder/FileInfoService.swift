import Foundation

struct FileInfoSnapshot: Identifiable, Equatable {
    let id: String
    let url: URL
    let name: String
    let path: String
    let kind: String
    let size: Int64?
    let isDirectory: Bool
    let isPackage: Bool
    let isHidden: Bool
    let created: Date?
    let modified: Date?
    let owner: String
    let group: String
    let posixPermissions: String
    let access: String
}

enum FileInfoService {
    static func snapshot(for url: URL) throws -> FileInfoSnapshot {
        let keys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isExecutableKey,
            .isHiddenKey,
            .isPackageKey,
            .isReadableKey,
            .isWritableKey,
            .localizedTypeDescriptionKey,
            .totalFileAllocatedSizeKey,
        ]
        let values = try url.resourceValues(forKeys: keys)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let isDirectory = values.isDirectory == true
        let mode = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        let owner = attributes[.ownerAccountName] as? String ?? "Unknown"
        let group = attributes[.groupOwnerAccountName] as? String ?? "Unknown"
        let size =
            isDirectory
            ? nil
            : Int64(values.fileSize ?? values.totalFileAllocatedSize ?? (attributes[.size] as? NSNumber)?.intValue ?? 0)

        return FileInfoSnapshot(
            id: url.path,
            url: url,
            name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            path: url.path,
            kind: values.localizedTypeDescription ?? (isDirectory ? "Folder" : "File"),
            size: size,
            isDirectory: isDirectory,
            isPackage: values.isPackage == true || url.pathExtension.lowercased() == "app",
            isHidden: values.isHidden == true,
            created: values.creationDate,
            modified: values.contentModificationDate,
            owner: owner,
            group: group,
            posixPermissions: String(format: "%03o", mode & 0o777),
            access: accessText(
                readable: values.isReadable, writable: values.isWritable, executable: values.isExecutable)
        )
    }

    private static func accessText(readable: Bool?, writable: Bool?, executable: Bool?) -> String {
        var parts: [String] = []
        if readable == true { parts.append("Read") }
        if writable == true { parts.append("Write") }
        if executable == true { parts.append("Execute") }
        return parts.isEmpty ? "No access" : parts.joined(separator: " / ")
    }
}
