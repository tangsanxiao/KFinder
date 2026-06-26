import Foundation

enum AgentInboxScanner {
    static func scan(workspaces: [Workspace], stars: [StarItem]) async -> [AgentInboxProject] {
        let sessions = await SessionScanner.scan(agents: [.claude, .codex])
        var projectURLsByPath: [String: URL] = [:]

        for session in sessions {
            guard let path = session.projectPath else { continue }
            let url = URL(fileURLWithPath: path)
            projectURLsByPath[url.standardizedFileURL.path] = url
        }
        for workspace in workspaces {
            for directory in workspace.directories {
                let url = URL(fileURLWithPath: directory.path)
                projectURLsByPath[url.standardizedFileURL.path] = url
            }
        }
        for star in stars {
            let url = URL(fileURLWithPath: star.path)
            projectURLsByPath[url.standardizedFileURL.path] = url
        }

        var projects: [AgentInboxProject] = []
        for url in projectURLsByPath.values.sorted(by: {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }) {
            let projectSessions = sessions.filter { session in
                guard let path = session.projectPath else { return false }
                return URL(fileURLWithPath: path).standardizedFileURL.path == url.standardizedFileURL.path
            }
            let snapshot = await GitStatusService.snapshot(for: url)
            let changes = snapshot.map { GitStatusService.recentChanges(in: $0, limit: 30) } ?? []
            let findings = AgentRiskAnalyzer.findings(for: changes)
            let extracted = await extractedItems(from: projectSessions)
            let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            projects.append(
                AgentInboxProject(
                    id: url.path,
                    name: name,
                    url: url,
                    sessions: projectSessions,
                    gitSnapshot: snapshot,
                    recentChanges: changes,
                    findings: findings,
                    extractedItems: Array(extracted.prefix(8)),
                    commitMessageDraft: AgentRiskAnalyzer.commitMessageDraft(projectName: name, changes: changes)
                ))
        }

        return projects.sorted { lhs, rhs in
            lhs.latestActivity > rhs.latestActivity
        }
    }

    private static func extractedItems(from sessions: [SessionSummary]) async -> [AgentTodoDecision] {
        var result: [AgentTodoDecision] = []
        for session in sessions.prefix(8) {
            let transcript = await SessionScanner.transcript(for: session.url)
            result.append(contentsOf: AgentRiskAnalyzer.extractedItems(from: transcript, sessionURL: session.url))
        }
        return result
    }
}
