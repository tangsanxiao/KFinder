import Foundation

enum AgentRiskAnalyzer {
    private static let sensitivePathFragments = [
        ".env", ".ssh", "id_rsa", "id_ed25519", "credentials", "secrets", "private_key", "service-account",
    ]

    private static let secretPatterns: [(name: String, regex: NSRegularExpression)] = [
        ("OpenAI-style API key", try! NSRegularExpression(pattern: #"sk-[A-Za-z0-9_\-]{20,}"#)),
        ("GitHub token", try! NSRegularExpression(pattern: #"gh[pousr]_[A-Za-z0-9_]{20,}"#)),
        ("Private key block", try! NSRegularExpression(pattern: #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#)),
        (
            "Generic API token",
            try! NSRegularExpression(pattern: #"(?i)(api[_-]?key|token|secret)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{16,}"#)
        ),
    ]

    static func findings(for changes: [RecentChange]) -> [AgentRiskFinding] {
        var result: [AgentRiskFinding] = []
        for change in changes {
            let lowerPath = change.url.path.lowercased()
            if let fragment = sensitivePathFragments.first(where: { lowerPath.contains($0) }) {
                result.append(
                    AgentRiskFinding(
                        id: "path:\(change.url.path):\(fragment)",
                        level: .high,
                        title: "Sensitive path changed",
                        detail: change.url.lastPathComponent,
                        url: change.url
                    ))
            }
            if let secret = secretFinding(in: change.url) {
                result.append(secret)
            }
            if change.status == .deleted {
                result.append(
                    AgentRiskFinding(
                        id: "deleted:\(change.url.path)",
                        level: .medium,
                        title: "File deleted",
                        detail: change.url.lastPathComponent,
                        url: change.url
                    ))
            }
        }
        return result
    }

    static func commitMessageDraft(projectName: String, changes: [RecentChange]) -> String {
        guard !changes.isEmpty else { return "chore: update \(projectName)" }
        let nouns = changes.prefix(4).map { change in
            change.url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        }
        let subject = nouns.joined(separator: ", ")
        let prefix = changes.contains { $0.status == .added } ? "feat" : "chore"
        return "\(prefix): update \(subject)"
    }

    static func extractedItems(from transcript: SessionTranscript, sessionURL: URL) -> [AgentTodoDecision] {
        transcript.messages.flatMap { message -> [AgentTodoDecision] in
            let lines = message.text.components(separatedBy: .newlines)
            return lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()
                let kind: AgentTodoDecision.Kind?
                if lower.contains("todo") || lower.contains("待办") || lower.contains("next step")
                    || lower.contains("下一步")
                {
                    kind = .todo
                } else if lower.contains("decision") || lower.contains("决定") || lower.contains("结论") {
                    kind = .decision
                } else {
                    kind = nil
                }
                guard let kind, !trimmed.isEmpty else { return nil }
                return AgentTodoDecision(
                    id: "\(sessionURL.path)#\(message.id)#\(trimmed.hashValue)",
                    kind: kind,
                    text: trimmed,
                    sessionURL: sessionURL
                )
            }
        }
    }

    private static func secretFinding(in url: URL) -> AgentRiskFinding? {
        guard isProbablyText(url),
            let data = try? Data(contentsOf: url),
            data.count <= 512 * 1024,
            let text = String(data: data, encoding: .utf8)
        else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in secretPatterns where pattern.regex.firstMatch(in: text, range: range) != nil {
            return AgentRiskFinding(
                id: "secret:\(url.path):\(pattern.name)",
                level: .high,
                title: "Potential secret",
                detail: "\(pattern.name) in \(url.lastPathComponent)",
                url: url
            )
        }
        return nil
    }

    private static func isProbablyText(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return true }
        return [
            "env", "txt", "md", "json", "yml", "yaml", "toml", "xml", "plist", "swift", "js", "ts", "tsx", "jsx",
            "py", "rb", "go", "rs", "java", "kt", "sh", "zsh", "bash", "sql", "csv",
        ].contains(ext)
    }
}
