import Foundation
import Testing

@testable import XFinder

@Test func fileInfoSnapshotReadsBasicMetadata() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderInfo-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("note.txt")
    try "hello".write(to: file, atomically: true, encoding: .utf8)

    let snapshot = try FileInfoService.snapshot(for: file)

    #expect(snapshot.name == "note.txt")
    #expect(snapshot.path == file.path)
    #expect(snapshot.size == 5)
    #expect(!snapshot.isDirectory)
    #expect(!snapshot.posixPermissions.isEmpty)
    #expect(snapshot.access.contains("Read"))
}
