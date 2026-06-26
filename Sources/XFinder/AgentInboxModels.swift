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
    var extractedItems: [AgentTodoDecision]
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

struct AgentInboxPreferences: Codable, Equatable {
    var hiddenProjectPaths: Set<String> = []
    var pinnedProjectPaths: Set<String> = []
}

enum AgentInboxProjectCatalog {
    static func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func key(for project: AgentInboxProject) -> String {
        key(for: project.url)
    }

    static func visibleProjects(
        _ projects: [AgentInboxProject],
        preferences: AgentInboxPreferences,
        showsHidden: Bool
    ) -> [AgentInboxProject] {
        projects
            .filter { project in
                showsHidden || !preferences.hiddenProjectPaths.contains(key(for: project))
            }
            .sorted { lhs, rhs in
                let lhsKey = key(for: lhs)
                let rhsKey = key(for: rhs)
                let lhsHidden = preferences.hiddenProjectPaths.contains(lhsKey)
                let rhsHidden = preferences.hiddenProjectPaths.contains(rhsKey)
                if lhsHidden != rhsHidden { return !lhsHidden }

                let lhsPinned = preferences.pinnedProjectPaths.contains(lhsKey)
                let rhsPinned = preferences.pinnedProjectPaths.contains(rhsKey)
                if lhsPinned != rhsPinned { return lhsPinned }

                if lhs.latestActivity != rhs.latestActivity { return lhs.latestActivity > rhs.latestActivity }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
