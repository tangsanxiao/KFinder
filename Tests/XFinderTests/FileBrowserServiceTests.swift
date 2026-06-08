import Foundation
import Testing

@testable import XFinder

@Test func contentsHidesDotFilesAndSortsFoldersFirst() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderFB-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: root.appendingPathComponent("Beta"), withIntermediateDirectories: true)
    try "x".write(to: root.appendingPathComponent("alpha.txt"), atomically: true, encoding: .utf8)
    try "x".write(to: root.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

    let items = try FileBrowserService.contents(of: root)
    let names = items.map(\.name)

    #expect(names == ["Beta", "alpha.txt"])  // folders first, then files; dotfile excluded
    #expect(items.first?.isDirectory == true)
}
