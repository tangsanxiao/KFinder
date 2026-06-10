import Foundation
import Testing

@testable import XFinder

// MARK: - Pure porcelain parsing

@Test func parsePorcelainMapsStatuses() {
    let root = URL(fileURLWithPath: "/repo")
    let output = """
         M Sources/App.swift
        ?? notes.md
        A  new.swift
         D gone.swift
        R  old.swift -> renamed.swift
        UU conflict.swift
        ?? Untracked Dir/
        """
    let statuses = GitStatusService.parsePorcelain(output, repoRoot: root)

    #expect(statuses["/repo/Sources/App.swift"] == .modified)
    #expect(statuses["/repo/notes.md"] == .untracked)
    #expect(statuses["/repo/new.swift"] == .added)
    #expect(statuses["/repo/gone.swift"] == .deleted)
    #expect(statuses["/repo/renamed.swift"] == .renamed)
    #expect(statuses["/repo/conflict.swift"] == .conflicted)
    #expect(statuses["/repo/Untracked Dir"] == .untracked)
    #expect(statuses["/repo/old.swift"] == nil)  // rename keys the new path
}

@Test func snapshotAggregatesDirectoryStatus() {
    let root = URL(fileURLWithPath: "/repo")
    let snapshot = GitDirectorySnapshot(
        repoRoot: root,
        branch: "main",
        fileStatuses: ["/repo/Sources/App.swift": .modified],
        recentCommits: []
    )

    #expect(snapshot.status(forPath: "/repo/Sources", isDirectory: true) == .containsChanges)
    #expect(snapshot.status(forPath: "/repo/Sources/App.swift", isDirectory: false) == .modified)
    #expect(snapshot.status(forPath: "/repo/Tests", isDirectory: true) == nil)
    #expect(snapshot.status(forPath: "/repo/SourcesOther", isDirectory: true) == nil)  // no prefix false-positive
}

@Test func parseLogSplitsHashSubjectDate() {
    let commits = GitStatusService.parseLog("abc1234\tFix the thing\t2 hours ago\ndef5678\tAdd feature\t3 days ago")
    #expect(commits.count == 2)
    #expect(commits[0].id == "abc1234")
    #expect(commits[0].subject == "Fix the thing")
    #expect(commits[1].relativeDate == "3 days ago")
}

// MARK: - Integration against a real temp repo

@Test func snapshotReadsARealRepository() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderGit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    func git(_ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
    }

    try git(["init", "-b", "main"])
    try git(["config", "user.email", "test@example.com"])
    try git(["config", "user.name", "Test"])
    try "v1".write(to: root.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
    try git(["add", "."])
    try git(["commit", "-m", "initial commit"])
    try "v2".write(to: root.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
    try "new".write(to: root.appendingPathComponent("untracked.txt"), atomically: true, encoding: .utf8)

    let snapshot = try #require(await GitStatusService.snapshot(for: root))

    #expect(snapshot.branch == "main")
    #expect(snapshot.recentCommits.first?.subject == "initial commit")
    // /tmp is a symlink on macOS; compare standardized paths via suffix.
    let statusNames = Set(snapshot.fileStatuses.keys.map { URL(fileURLWithPath: $0).lastPathComponent })
    #expect(statusNames == ["tracked.txt", "untracked.txt"])

    let notARepo = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderNoGit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: notARepo, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: notARepo) }
    #expect(await GitStatusService.snapshot(for: notARepo) == nil)
}
