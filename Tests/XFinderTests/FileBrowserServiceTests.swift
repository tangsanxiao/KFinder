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

@Test func contentsCanIncludeHiddenFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderFB-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(
        at: root.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    try "x".write(to: root.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try "x".write(to: root.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)

    let hiddenNames = try FileBrowserService.contents(of: root).map(\.name)
    let visibleNames = try FileBrowserService.contents(of: root, includingHidden: true).map(\.name)

    #expect(hiddenNames == ["visible.txt"])
    #expect(visibleNames == [".claude", ".env", "visible.txt"])
}

@Test func appPackagesCanBrowseInlineOnlyInHiddenMode() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderFB-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let app = root.appendingPathComponent("Demo.app", isDirectory: true)
    try FileManager.default.createDirectory(
        at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)

    let item = try #require(FileBrowserService.contents(of: root).first)

    #expect(item.isPackage)
    #expect(!item.canBrowseInline)
    #expect(item.canBrowseInline(showHiddenItems: true))
}
