import Foundation

/// Git state of one path, for the file-row badge.
enum FileGitStatus: Sendable, Equatable {
    case modified
    case untracked
    case added
    case deleted
    case renamed
    case conflicted
    /// A folder whose contents (not the folder itself) have changes.
    case containsChanges

    var badgeLetter: String {
        switch self {
        case .modified: "M"
        case .untracked: "U"
        case .added: "A"
        case .deleted: "D"
        case .renamed: "R"
        case .conflicted: "!"
        case .containsChanges: "•"
        }
    }
}

struct GitCommitSummary: Sendable, Identifiable, Equatable {
    let id: String  // short hash
    let subject: String
    let relativeDate: String
}

/// One line of a unified diff, classified for colored rendering.
struct DiffLine: Identifiable, Equatable {
    enum Kind: Equatable {
        case addition
        case deletion
        case hunk
        case header
        case context
    }

    let id: Int
    let kind: Kind
    let text: String
}

/// A changed file plus its modification time, for the "Recent changes" list —
/// the AI-agent workflow's core question: "what did the agent just touch?"
struct RecentChange: Identifiable, Equatable {
    let url: URL
    let status: FileGitStatus
    let modified: Date

    var id: String { url.path }
}

/// One git read of a directory: repo info for the status card plus per-path
/// statuses for the row badges. Immutable snapshot — panes refetch on reload
/// (FSEvents already triggers reloads on any change, including `.git`).
struct GitDirectorySnapshot: Sendable, Equatable {
    let repoRoot: URL
    let branch: String
    /// Absolute file path → status. Directories are not listed; use
    /// `status(forPath:isDirectory:)` to aggregate.
    let fileStatuses: [String: FileGitStatus]
    let recentCommits: [GitCommitSummary]

    var changedPathCount: Int { fileStatuses.count }

    func status(forPath path: String, isDirectory: Bool) -> FileGitStatus? {
        if let direct = fileStatuses[path] { return direct }
        guard isDirectory else { return nil }
        let prefix = path.hasSuffix("/") ? path : path + "/"
        return fileStatuses.keys.contains { $0.hasPrefix(prefix) } ? .containsChanges : nil
    }
}

enum GitStatusService {
    /// Most-recently-modified changed files first. Pure (the mtime lookup is
    /// injected) so it's unit-testable; deleted files are skipped (no file to
    /// stat or open). `limit` caps the list for the compact card.
    static func recentChanges(
        statuses: [String: FileGitStatus],
        limit: Int = 12,
        modificationDate: (String) -> Date?
    ) -> [RecentChange] {
        statuses.compactMap { path, status -> RecentChange? in
            guard status != .deleted, let date = modificationDate(path) else { return nil }
            return RecentChange(url: URL(fileURLWithPath: path), status: status, modified: date)
        }
        .sorted { $0.modified > $1.modified }
        .prefix(limit)
        .map { $0 }
    }

    /// Convenience over a snapshot using the real filesystem mtime.
    static func recentChanges(in snapshot: GitDirectorySnapshot, limit: Int = 12) -> [RecentChange] {
        recentChanges(statuses: snapshot.fileStatuses, limit: limit) { path in
            (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        }
    }

    /// Reads the git state of `directory` off the calling actor.
    /// Returns nil when the directory is not inside a git work tree.
    static func snapshot(for directory: URL) async -> GitDirectorySnapshot? {
        guard let rootOutput = await run(["rev-parse", "--show-toplevel"], in: directory) else { return nil }
        let rootPath = rootOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty else { return nil }
        let root = URL(fileURLWithPath: rootPath)

        async let branchOutput = run(["rev-parse", "--abbrev-ref", "HEAD"], in: directory)
        async let statusOutput = run(["status", "--porcelain"], in: directory)
        async let logOutput = run(["log", "-5", "--pretty=format:%h\t%s\t%cr"], in: directory)

        let branch = (await branchOutput)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
        let statuses = parsePorcelain(await statusOutput ?? "", repoRoot: root)
        let commits = parseLog(await logOutput ?? "")

        return GitDirectorySnapshot(repoRoot: root, branch: branch, fileStatuses: statuses, recentCommits: commits)
    }

    /// Parses `git status --porcelain` (v1) into absolute-path statuses.
    /// Pure and unit-tested; rename lines use their new path, quoted paths are
    /// unquoted naively (good enough for badge display).
    static func parsePorcelain(_ output: String, repoRoot: URL) -> [String: FileGitStatus] {
        var result: [String: FileGitStatus] = [:]
        for line in output.split(separator: "\n") {
            guard line.count > 3 else { continue }
            let x = line[line.startIndex]
            let y = line[line.index(after: line.startIndex)]
            var pathPart = String(line.dropFirst(3))
            if let arrowRange = pathPart.range(of: " -> ") {
                pathPart = String(pathPart[arrowRange.upperBound...])
            }
            if pathPart.hasPrefix("\""), pathPart.hasSuffix("\"") {
                pathPart = String(pathPart.dropFirst().dropLast())
            }
            // Directory entries (untracked dirs) end with "/" — key the dir itself.
            if pathPart.hasSuffix("/") { pathPart = String(pathPart.dropLast()) }

            let status: FileGitStatus
            switch (x, y) {
            case ("?", "?"): status = .untracked
            case ("U", _), (_, "U"), ("D", "D"), ("A", "A"): status = .conflicted
            case ("R", _): status = .renamed
            case ("A", _): status = .added
            case ("D", _), (_, "D"): status = .deleted
            default: status = .modified
            }
            let absolute = repoRoot.appendingPathComponent(pathPart).path
            result[absolute] = status
        }
        return result
    }

    static func parseLog(_ output: String) -> [GitCommitSummary] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { return nil }
            return GitCommitSummary(id: String(parts[0]), subject: String(parts[1]), relativeDate: String(parts[2]))
        }
    }

    /// `git diff` of a single file for the diff viewer. Untracked/added files
    /// have no tracked baseline, so they're diffed against /dev/null to show
    /// the whole file as additions. Tolerates git's non-zero "differences"
    /// exit code (1) — only nil on a real failure.
    static func diff(for fileURL: URL, repoRoot: URL, status: FileGitStatus) async -> String? {
        let path = fileURL.path
        if status == .untracked || status == .added {
            return await runAllowingDiffExit(
                ["-C", repoRoot.path, "diff", "--no-index", "--", "/dev/null", path])
        }
        return await runAllowingDiffExit(["-C", repoRoot.path, "diff", "--", path])
    }

    /// Pure classification of unified-diff lines for colored rendering.
    static func parseDiff(_ output: String) -> [DiffLine] {
        output.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map { index, raw in
            let line = String(raw)
            let kind: DiffLine.Kind
            if line.hasPrefix("+++") || line.hasPrefix("---") || line.hasPrefix("diff ")
                || line.hasPrefix("index ") || line.hasPrefix("new file") || line.hasPrefix("deleted file")
                || line.hasPrefix("rename ") || line.hasPrefix("similarity ") || line.hasPrefix("\\ ")
            {
                kind = .header
            } else if line.hasPrefix("@@") {
                kind = .hunk
            } else if line.hasPrefix("+") {
                kind = .addition
            } else if line.hasPrefix("-") {
                kind = .deletion
            } else {
                kind = .context
            }
            return DiffLine(id: index, kind: kind, text: line)
        }
    }

    private static func runAllowingDiffExit(_ arguments: [String]) async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()
            do { try process.run() } catch { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            // git diff exits 0 (no diff) or 1 (differences); both are fine.
            guard process.terminationStatus <= 1 else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }

    private static func run(_ arguments: [String], in directory: URL) async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", directory.path] + arguments
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = Pipe()
            do { try process.run() } catch { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }
}
