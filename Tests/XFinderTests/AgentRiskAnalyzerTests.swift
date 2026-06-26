import Foundation
import Testing

@testable import XFinder

@Test func agentRiskFlagsSensitivePathsAndSecrets() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("XFinderRisk-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let env = root.appendingPathComponent(".env")
    try "OPENAI_API_KEY=sk-testtoken-testtoken-testtoken".write(to: env, atomically: true, encoding: .utf8)
    let config = root.appendingPathComponent("config.json")
    try #"{"name":"safe"}"#.write(to: config, atomically: true, encoding: .utf8)

    let findings = AgentRiskAnalyzer.findings(for: [
        RecentChange(url: env, status: .modified, modified: Date(timeIntervalSince1970: 20)),
        RecentChange(url: config, status: .modified, modified: Date(timeIntervalSince1970: 10)),
    ])

    #expect(findings.contains { $0.title == "Sensitive path changed" && $0.level == .high })
    #expect(findings.contains { $0.title == "Potential secret" && $0.level == .high })
    #expect(!findings.contains { $0.url == config })
}

@Test func agentRiskAddsDeletedFileWarning() {
    let change = RecentChange(
        url: URL(fileURLWithPath: "/repo/obsolete.swift"),
        status: .deleted,
        modified: Date(timeIntervalSince1970: 1)
    )

    let findings = AgentRiskAnalyzer.findings(for: [change])

    #expect(findings.count == 1)
    #expect(findings.first?.level == .medium)
    #expect(findings.first?.title == "File deleted")
}

@Test func agentCommitDraftUsesChangeShape() {
    let added = RecentChange(
        url: URL(fileURLWithPath: "/repo/AgentInboxView.swift"),
        status: .added,
        modified: Date()
    )
    let modified = RecentChange(
        url: URL(fileURLWithPath: "/repo/agent-risk_analyzer.swift"),
        status: .modified,
        modified: Date()
    )

    #expect(AgentRiskAnalyzer.commitMessageDraft(projectName: "XFinder", changes: []) == "chore: update XFinder")
    #expect(
        AgentRiskAnalyzer.commitMessageDraft(projectName: "XFinder", changes: [added, modified])
            == "feat: update AgentInboxView, agent risk analyzer")
    #expect(
        AgentRiskAnalyzer.commitMessageDraft(projectName: "XFinder", changes: [modified])
            == "chore: update agent risk analyzer")
}

@Test func agentTranscriptExtractionFindsTodosAndDecisions() {
    let transcript = SessionTranscript(
        messages: [
            SessionMessage(id: 1, role: .user, text: "决定: 先做本地 Agent Inbox"),
            SessionMessage(id: 2, role: .assistant, text: "TODO: add risk analyzer tests\n普通说明"),
            SessionMessage(id: 3, role: .assistant, text: "Next step: wire sidebar entry"),
        ],
        exactTokens: 100
    )

    let items = AgentRiskAnalyzer.extractedItems(
        from: transcript,
        sessionURL: URL(fileURLWithPath: "/sessions/test.jsonl")
    )

    #expect(items.map(\.kind) == [.decision, .todo, .todo])
    #expect(
        items.map(\.text) == ["决定: 先做本地 Agent Inbox", "TODO: add risk analyzer tests", "Next step: wire sidebar entry"])
}

@Test func agentInboxProjectSummarizesLatestActivityAndRisk() {
    let lowChange = RecentChange(
        url: URL(fileURLWithPath: "/repo/a.swift"),
        status: .modified,
        modified: Date(timeIntervalSince1970: 10)
    )
    let laterChange = RecentChange(
        url: URL(fileURLWithPath: "/repo/b.swift"),
        status: .modified,
        modified: Date(timeIntervalSince1970: 30)
    )
    let snapshot = GitDirectorySnapshot(
        repoRoot: URL(fileURLWithPath: "/repo"),
        branch: "main",
        fileStatuses: [
            "/repo/a.swift": .modified,
            "/repo/b.swift": .modified,
        ],
        recentCommits: []
    )
    let project = AgentInboxProject(
        id: "/repo",
        name: "repo",
        url: URL(fileURLWithPath: "/repo"),
        sessions: [
            SessionSummary(
                agent: .codex,
                url: URL(fileURLWithPath: "/sessions/s.jsonl"),
                title: "older",
                project: "repo",
                projectPath: "/repo",
                modified: Date(timeIntervalSince1970: 20),
                sizeBytes: 40
            )
        ],
        gitSnapshot: snapshot,
        recentChanges: [lowChange, laterChange],
        findings: [
            AgentRiskFinding(id: "m", level: .medium, title: "Medium", detail: "m", url: nil),
            AgentRiskFinding(id: "h", level: .high, title: "High", detail: "h", url: nil),
        ],
        extractedItems: [],
        commitMessageDraft: "chore: update repo"
    )

    #expect(project.latestActivity == Date(timeIntervalSince1970: 30))
    #expect(project.riskLevel == .high)
    #expect(project.changedCount == 2)
}
