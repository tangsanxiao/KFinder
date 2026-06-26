import SwiftUI

struct AgentInboxDetail: View {
    let project: AgentInboxProject
    let chinese: Bool
    let claudeEnabled: Bool
    let isExtractingItems: Bool
    let onOpenProject: () -> Void
    let onOpenTerminal: () -> Void
    let onOpenClaudeCode: () -> Void
    let onCopyCommitMessage: () -> Void
    let onOpenSession: (SessionSummary) -> Void
    let onOpenChange: (RecentChange) -> Void
    let onShowDiff: (RecentChange) -> Void

    private func loc(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryGrid
                if !project.findings.isEmpty { findingsSection }
                changesSection
                sessionsSection
                if isExtractingItems || !project.extractedItems.isEmpty { extractedSection }
                commitSection
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: project.riskLevel.systemImage)
                .font(.system(size: 22))
                .foregroundStyle(color(for: project.riskLevel))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.system(size: 19, weight: .semibold))
                Text(project.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button(action: onOpenProject) {
                Label(loc("打开项目", "Open Project"), systemImage: "folder")
            }
            Button(action: onOpenTerminal) {
                Label(loc("终端", "Terminal"), systemImage: "terminal")
            }
            if claudeEnabled {
                Button(action: onOpenClaudeCode) {
                    Label("Claude Code", systemImage: "apple.terminal")
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            metric(loc("Agent 会话", "Agent sessions"), "\(project.sessions.count)", "bubble.left.and.bubble.right")
            metric(loc("未提交变更", "Uncommitted"), "\(project.changedCount)", "plusminus")
            metric(loc("风险", "Risk"), project.riskLevel.title, project.riskLevel.systemImage)
            metric(loc("分支", "Branch"), project.gitSnapshot?.branch ?? "—", "arrow.triangle.branch")
        }
    }

    private func metric(_ title: String, _ value: String, _ image: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: image)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }

    private var findingsSection: some View {
        section(title: loc("风险提示", "Risk findings"), image: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(project.findings) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: finding.level.systemImage)
                            .foregroundStyle(color(for: finding.level))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(finding.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(finding.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private var changesSection: some View {
        section(title: loc("变更审查", "Change review"), image: "plusminus") {
            if project.recentChanges.isEmpty {
                Text(loc("当前没有未提交文件变更。", "No uncommitted file changes."))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(project.recentChanges) { change in
                        HStack(spacing: 8) {
                            GitStatusBadge(status: change.status)
                            FileIconView(url: change.url, size: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.url.lastPathComponent)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(relativePath(change.url))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(Self.relativeFormatter.localizedString(for: change.modified, relativeTo: Date()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                onShowDiff(change)
                            } label: {
                                Image(systemName: "plusminus")
                            }
                            .buttonStyle(.plain)
                            Button {
                                onOpenChange(change)
                            } label: {
                                Image(systemName: "arrow.up.forward.square")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private var sessionsSection: some View {
        section(title: loc("相关会话", "Related sessions"), image: "bubble.left.and.bubble.right") {
            if project.sessions.isEmpty {
                Text(loc("没有关联会话。", "No related sessions."))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.sessions.prefix(8)) { session in
                        Button {
                            onOpenSession(session)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(session.agent.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Text(Self.dateFormatter.string(from: session.modified))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var extractedSection: some View {
        section(title: loc("决策 / 待办", "Decisions / todos"), image: "checklist") {
            if isExtractingItems {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(loc("正在读取相关会话…", "Reading related sessions…"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.extractedItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.kind == .todo ? "TODO" : "DEC")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(item.kind == .todo ? .orange : .blue)
                                .frame(width: 34, alignment: .leading)
                            Text(item.text)
                                .font(.system(size: 12))
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }

    private var commitSection: some View {
        section(title: loc("Commit message 草稿", "Commit message draft"), image: "text.badge.checkmark") {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.commitMessageDraft)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button(action: onCopyCommitMessage) {
                    Label(loc("复制草稿", "Copy draft"), systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
        }
    }

    private func section<Content: View>(title: String, image: String, @ViewBuilder content: () -> Content) -> some View
    {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: image)
                .font(.system(size: 13, weight: .semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }

    private func relativePath(_ url: URL) -> String {
        let base = project.url.path.hasSuffix("/") ? project.url.path : project.url.path + "/"
        return url.path.hasPrefix(base) ? String(url.path.dropFirst(base.count)) : url.path
    }

    private func color(for level: AgentRiskLevel) -> Color {
        switch level {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
