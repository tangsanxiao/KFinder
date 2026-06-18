import Foundation
import Testing

@testable import XFinder

/// Exercises the file-mutating store operations — the highest-risk code (data
/// loss) — against a real temp directory so collision handling is verified end
/// to end. The store is created with an isolated support directory so it never
/// touches the real Application Support.
@MainActor
private func makeFixture() throws -> (store: WorkspaceStore, root: URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = WorkspaceStore(supportDirectory: root.appendingPathComponent("support"))
    return (store, root)
}

private func writeFile(_ url: URL, _ contents: String = "x") throws {
    try contents.write(to: url, atomically: true, encoding: .utf8)
}

private func makeDir(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

@MainActor
@Test func movingMultipleFilesToTrashRemovesAllOfThem() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let files = (0..<3).map { root.appendingPathComponent("file\($0).txt") }
    for file in files { try writeFile(file) }

    // Mirrors the row context-menu loop: trash each selected file.
    for file in files { store.moveToTrash(file) }

    for file in files {
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
}

@MainActor
@Test func syncSkillMirrorsSourceOverDestinationsAndSkipsSelf() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    // source skill with two files; a stale destination with different content.
    let source = root.appendingPathComponent("source/my-skill", isDirectory: true)
    try makeDir(source)
    try writeFile(source.appendingPathComponent("SKILL.md"), "v2")
    try writeFile(source.appendingPathComponent("extra.txt"), "asset")

    let dest = root.appendingPathComponent("dest/my-skill", isDirectory: true)
    try makeDir(dest)
    try writeFile(dest.appendingPathComponent("SKILL.md"), "v1-old")
    try writeFile(dest.appendingPathComponent("removed.txt"), "should be gone")

    #expect(store.syncSkill(from: source, to: [dest, source]))  // source target is skipped

    #expect(try String(contentsOf: dest.appendingPathComponent("SKILL.md"), encoding: .utf8) == "v2")
    #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("extra.txt").path))
    // Mirror, not merge: stale file removed.
    #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("removed.txt").path))
    // Source untouched.
    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("SKILL.md").path))
}

@MainActor
@Test func consolidateSkillMovesToLibraryAndSymlinksLocations() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    store.settings.skillLibraryPath = root.appendingPathComponent("Library").path

    let copyA = root.appendingPathComponent("claude/my-skill", isDirectory: true)
    let copyB = root.appendingPathComponent("trae/my-skill", isDirectory: true)
    try makeDir(copyA)
    try makeDir(copyB)
    try writeFile(copyA.appendingPathComponent("SKILL.md"), "canonical")
    try writeFile(copyB.appendingPathComponent("SKILL.md"), "stale")

    #expect(store.consolidateSkill(name: "my-skill", canonicalSource: copyA, writableLocations: [copyA, copyB]))

    let libraryEntry = root.appendingPathComponent("Library/my-skill")
    #expect(FileManager.default.fileExists(atPath: libraryEntry.appendingPathComponent("SKILL.md").path))

    // Both locations are now symlinks pointing at the library entry.
    for location in [copyA, copyB] {
        let isLink = (try? location.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
        #expect(isLink)
        // Reading through the symlink yields the canonical content.
        let content = try String(contentsOf: location.appendingPathComponent("SKILL.md"), encoding: .utf8)
        #expect(content == "canonical")
    }
}

@MainActor
@Test func copyIntoFolderWithExistingNameDeduplicates() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("note.txt")
    try writeFile(source, "src")
    let dest = root.appendingPathComponent("dest", isDirectory: true)
    try makeDir(dest)
    try writeFile(dest.appendingPathComponent("note.txt"), "existing")

    store.copy(source, to: PaneDestination(id: UUID(), name: "dest", url: dest))

    #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("note.txt").path))
    #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("note 2.txt").path))
    // The original is preserved (copy, not move).
    #expect(FileManager.default.fileExists(atPath: source.path))
}

@MainActor
@Test func moveIntoFolderWithExistingNameDeduplicatesAndRemovesSource() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("a.txt")
    try writeFile(source)
    let dest = root.appendingPathComponent("dest", isDirectory: true)
    try makeDir(dest)
    try writeFile(dest.appendingPathComponent("a.txt"), "existing")

    store.move(source, toDirectory: dest)

    #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("a 2.txt").path))
    #expect(!FileManager.default.fileExists(atPath: source.path))
}

@MainActor
@Test func moveIntoSameFolderIsANoOp() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("a.txt")
    try writeFile(source)

    store.move(source, toDirectory: root)

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(store.statusMessage.contains("already"))
}

@MainActor
@Test func renameToExistingNameFailsAndKeepsBoth() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let a = root.appendingPathComponent("a.txt")
    let b = root.appendingPathComponent("b.txt")
    try writeFile(a)
    try writeFile(b)

    store.renameFile(a, to: "b.txt")

    #expect(store.lastError != nil)
    #expect(FileManager.default.fileExists(atPath: a.path))  // unchanged
    #expect(FileManager.default.fileExists(atPath: b.path))
}

@MainActor
@Test func renameSucceeds() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let a = root.appendingPathComponent("a.txt")
    try writeFile(a)

    store.renameFile(a, to: "renamed.txt")

    #expect(!FileManager.default.fileExists(atPath: a.path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("renamed.txt").path))
}

@MainActor
@Test func createFolderDeduplicatesNames() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let first = store.createFolder(in: root, named: "Untitled")
    let second = store.createFolder(in: root, named: "Untitled")

    #expect(first?.lastPathComponent == "Untitled")
    #expect(second?.lastPathComponent == "Untitled 2")
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Untitled").path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Untitled 2").path))
}

@MainActor
@Test func createMarkdownFileDeduplicatesFromOne() throws {
    let (store, root) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: root) }

    let first = store.createMarkdownFile(in: root)
    let second = store.createMarkdownFile(in: root)
    let third = store.createMarkdownFile(in: root)

    #expect(first?.lastPathComponent == "New.md")
    #expect(second?.lastPathComponent == "New 1.md")
    #expect(third?.lastPathComponent == "New 2.md")
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("New.md").path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("New 1.md").path))
    #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("New 2.md").path))
}
