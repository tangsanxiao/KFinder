import Foundation
import Testing

@testable import KFinder

private func waitForFile(_ url: URL, attempts: Int = 50) async -> Bool {
    for _ in 0..<attempts {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        try? await Task.sleep(for: .milliseconds(100))
    }
    return false
}

@MainActor
@Test func compressCreatesNamedZipInOutputDirectory() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("KFinderZip-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = WorkspaceStore(supportDirectory: root.appendingPathComponent("support"))
    let a = root.appendingPathComponent("a.txt")
    let b = root.appendingPathComponent("b.txt")
    try "aaa".write(to: a, atomically: true, encoding: .utf8)
    try "bbb".write(to: b, atomically: true, encoding: .utf8)

    store.compress([a, b], relativeTo: root, archiveName: "Bundle", into: root)

    let zip = root.appendingPathComponent("Bundle.zip")
    #expect(await waitForFile(zip))
    let size = (try? FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int) ?? 0
    #expect(size > 0)
}

@MainActor
@Test func compressDeduplicatesArchiveName() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("KFinderZip-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = WorkspaceStore(supportDirectory: root.appendingPathComponent("support"))
    let a = root.appendingPathComponent("a.txt")
    try "aaa".write(to: a, atomically: true, encoding: .utf8)

    store.compress([a], relativeTo: root, archiveName: "Bundle", into: root)
    #expect(await waitForFile(root.appendingPathComponent("Bundle.zip")))

    store.compress([a], relativeTo: root, archiveName: "Bundle", into: root)
    #expect(await waitForFile(root.appendingPathComponent("Bundle 2.zip")))
}
