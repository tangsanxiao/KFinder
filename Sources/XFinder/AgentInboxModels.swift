import Foundation

enum AgentRiskLevel: Int, Comparable, Sendable {
    case low
    case medium
    case high

    static func < (lhs: AgentRiskLevel, rhs: AgentRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var systemImage: String {
        switch self {
        case .low: "checkmark.seal"
        case .medium: "exclamationmark.triangle"
        case .high: "xmark.octagon"
        }
    }
}

struct AgentRiskFinding: Identifiable, Equatable, Sendable {
    let id: String
    let level: AgentRiskLevel
    let title: String
    let detail: String
    let url: URL?
}

struct AgentTodoDecision: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case decision
        case todo
    }

    let id: String
    let kind: Kind
    let text: String
    let sessionURL: URL
}

struct AgentInboxProject: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
    let sessions: [SessionSummary]
    let gitSnapshot: GitDirectorySnapshot?
    let recentChanges: [RecentChange]
    let findings: [AgentRiskFinding]
    let extractedItems: [AgentTodoDecision]
    let commitMessageDraft: String

    var latestActivity: Date {
        let sessionDate = sessions.map(\.modified).max() ?? .distantPast
        let changeDate = recentChanges.map(\.modified).max() ?? .distantPast
        return max(sessionDate, changeDate)
    }

    var riskLevel: AgentRiskLevel {
        findings.map(\.level).max() ?? .low
    }

    var changedCount: Int {
        gitSnapshot?.changedPathCount ?? 0
    }
}
