import Foundation
import Testing

@testable import XFinder

@Test func recursiveSearchFindsNestedFilesAndSkipsHiddenByDefault() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderSearch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let nested = root.appendingPathComponent("docs", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "hello".write(to: nested.appendingPathComponent("release-notes.md"), atomically: true, encoding: .utf8)
    try "hidden".write(to: root.appendingPathComponent(".release-secret.md"), atomically: true, encoding: .utf8)

    let visible = try await FileSearchService.search(in: root, query: "release")
    #expect(visible.map(\.relativePath) == ["docs/release-notes.md"])

    let includingHidden = try await FileSearchService.search(in: root, query: "release", includingHidden: true)
    #expect(includingHidden.map(\.name).contains(".release-secret.md"))
}

@Test func recursiveSearchCapsResults() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderSearch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    for index in 0..<5 {
        try "x".write(to: root.appendingPathComponent("match-\(index).txt"), atomically: true, encoding: .utf8)
    }

    let results = try FileSearchService.searchSync(in: root, query: "match", limit: 3)
    #expect(results.count == 3)
}
