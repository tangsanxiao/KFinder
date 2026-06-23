import Foundation

/// Scans each agent's session stores into a unified catalog. The list pass is
/// cheap (file stat + a short head read for title/project); full transcript
/// parsing happens lazily when a session is opened. Runs off the main actor.
enum SessionScanner {
    static func scan(agents: [SessionAgent] = SessionAgent.allCases) async -> [SessionSummary] {
        await Task.detached(priority: .userInitiated) { () -> [SessionSummary] in
            let fileManager = FileManager.default
            var summaries: [SessionSummary] = []

            for agent in agents {
                for root in agent.sessionRoots {
                    for url in jsonlFiles(in: root, fileManager: fileManager) {
                        guard let summary = summary(for: url, agent: agent) else { continue }
                        summaries.append(summary)
                    }
                }
            }
            // Newest first.
            return summaries.sorted { $0.modified > $1.modified }
        }.value
    }

    /// Full transcript parse for the viewer (reads the whole file).
    static func transcript(for url: URL) async -> SessionTranscript {
        await Task.detached(priority: .userInitiated) { () -> SessionTranscript in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return SessionTranscript(messages: [], exactTokens: 0)
            }
            var raw: [SessionMessage] = []
            content.enumerateLines { line, _ in
                guard let message = SessionParsing.message(fromLine: line) else { return }
                raw.append(message)
            }
            // Drop injected preambles, then renumber for stable ForEach ids.
            let stripped = SessionParsing.stripPreamble(raw).enumerated().map {
                SessionMessage(id: $0.offset, role: $0.element.role, text: $0.element.text)
            }
            let chars = stripped.reduce(0) { $0 + $1.text.count }
            return SessionTranscript(messages: stripped, exactTokens: SessionParsing.estimateTokens(chars: chars))
        }.value
    }

    /// Recursively collects `*.jsonl` files (sync — the enumerator iterator
    /// isn't available from an async context).
    private static func jsonlFiles(in root: URL, fileManager: FileManager) -> [URL] {
        guard
            let enumerator = fileManager.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles])
        else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            result.append(url)
        }
        return result
    }

    /// Cheap list metadata: stat for date/size, a bounded head read for the
    /// first human message (title) and the session's cwd (project).
    private static func summary(for url: URL, agent: SessionAgent) -> SessionSummary? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modified = values?.contentModificationDate ?? .distantPast
        let size = Int64(values?.fileSize ?? 0)
        guard size > 0 else { return nil }

        var title = ""
        var cwd: String?
        // Read only the first chunk of lines — enough for the meta line and the
        // first real user message — instead of the whole (possibly huge) file.
        if let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            // 256KB: enough to get past a large AGENTS.md/attachment preamble
            // to the first real user prompt without reading whole huge files.
            let head = (try? handle.read(upToCount: 256 * 1024)) ?? Data()
            let text = String(decoding: head, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
                if cwd == nil { cwd = SessionParsing.cwd(fromLine: line) }
                if title.isEmpty, let message = SessionParsing.message(fromLine: line),
                    message.role == .user, !SessionParsing.isPreamble(message.text)
                {
                    title = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                }
                if !title.isEmpty, cwd != nil { break }
            }
        }

        let project = cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—"
        if title.count > 140 { title = String(title.prefix(140)) + "…" }
        return SessionSummary(
            agent: agent,
            url: url,
            title: title.isEmpty ? url.deletingPathExtension().lastPathComponent : title,
            project: project,
            modified: modified,
            sizeBytes: size
        )
    }
}
