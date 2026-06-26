import SwiftUI

struct AgentInboxView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let isSidebarVisible: Bool

    @State private var projects: [AgentInboxProject] = []
    @State private var isLoading = true
    @State private var selectedID: AgentInboxProject.ID?
    @State private var query = ""
    @State private var showsDiff = false
    @State private var diffFileName = ""
    @State private var diffLoading = false
    @State private var diffLines: [DiffLine] = []
    @State private var diffTask: Task<Void, Never>?

    private var chinese: Bool { store.settings.language.isChineseResolved }
    private func loc(_ zh: String, _ en: String) -> String { store.loc(zh, en) }

    private var filtered: [AgentInboxProject] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return projects }
        return projects.filter { project in
            project.name.localizedCaseInsensitiveContains(q)
                || project.url.path.localizedCaseInsensitiveContains(q)
                || project.sessions.contains { $0.title.localizedCaseInsensitiveContains(q) }
        }
    }

    private var selected: AgentInboxProject? {
        filtered.first { $0.id == selectedID } ?? filtered.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !isLoading, !projects.isEmpty {
                filterBar
                Divider()
            }
            content
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { await reload() }
        .sheet(isPresented: $showsDiff, onDismiss: { diffTask?.cancel() }) {
            DiffSheet(
                fileName: diffFileName,
                chinese: chinese,
                isLoading: diffLoading,
                lines: diffLines,
                claudeEnabled: false,
                onExplain: {},
                onClose: { showsDiff = false }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Agent Inbox")
                .font(.system(size: 15, weight: .semibold))
            if !isLoading {
                Text(loc("\(projects.count) 个项目", "\(projects.count) projects"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .helpTip(loc("重新扫描", "Rescan"))
        }
        .padding(.leading, isSidebarVisible ? 14 : 112)
        .padding(.trailing, 14)
        .frame(height: 44)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField(loc("搜索项目/会话", "Search projects / sessions"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            Spacer()
            Text(loc("本地扫描 Claude / Codex", "Local Claude / Codex scan"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, isSidebarVisible ? 14 : 18)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if projects.isEmpty {
            EmptyStateView(
                title: loc("没有发现 agent 活动", "No agent activity found"),
                systemImage: "tray",
                description: loc(
                    "未在 Claude / Codex 会话或当前工作区中找到可聚合的项目。",
                    "No Claude / Codex sessions or workspace projects were found."
                ))
        } else {
            HStack(spacing: 0) {
                projectList.frame(width: 340)
                Divider()
                if let selected {
                    AgentInboxDetail(
                        project: selected,
                        chinese: chinese,
                        claudeEnabled: store.settings.claudeIntegrationEnabled,
                        onOpenProject: { openProject(selected.url) },
                        onOpenTerminal: { store.openTerminal(at: selected.url) },
                        onOpenClaudeCode: { store.openClaudeCode(at: selected.url) },
                        onCopyCommitMessage: { copyCommitMessage(selected.commitMessageDraft) },
                        onOpenChange: { openChange($0) },
                        onShowDiff: { showDiff(for: $0, project: selected) }
                    )
                } else {
                    EmptyStateView(
                        title: loc("选择一个项目", "Select a project"),
                        systemImage: "hand.point.left",
                        description: loc("点击左侧项目查看 review 摘要。", "Click a project to review its changes."))
                }
            }
        }
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { project in
                    AgentInboxProjectRow(project: project, isSelected: project.id == selected?.id, chinese: chinese)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = project.id }
                }
            }
        }
    }

    private func reload() async {
        isLoading = true
        let loaded = await AgentInboxScanner.scan(workspaces: store.workspaces, stars: store.stars)
        projects = loaded
        if selectedID == nil || !loaded.contains(where: { $0.id == selectedID }) {
            selectedID = loaded.first?.id
        }
        isLoading = false
    }

    private func openProject(_ url: URL) {
        store.activePanel = .files
        _ = store.openLocation(url: url, title: url.lastPathComponent, in: store.focusedPaneID)
    }

    private func openChange(_ change: RecentChange) {
        store.activePanel = .files
        let parent = change.url.deletingLastPathComponent()
        _ = store.openLocation(url: parent, title: parent.lastPathComponent, in: store.focusedPaneID)
    }

    private func showDiff(for change: RecentChange, project: AgentInboxProject) {
        guard let snapshot = project.gitSnapshot else { return }
        diffFileName = change.url.lastPathComponent
        diffLines = []
        diffLoading = true
        showsDiff = true
        diffTask?.cancel()
        diffTask = Task {
            let output = await GitStatusService.diff(
                for: change.url, repoRoot: snapshot.repoRoot, status: change.status)
            if Task.isCancelled { return }
            guard let output else {
                diffLines = []
                diffLoading = false
                store.lastError = loc(
                    "无法加载 diff: \(change.url.lastPathComponent)", "Failed to load diff: \(change.url.lastPathComponent)"
                )
                return
            }
            diffLines = GitStatusService.parseDiff(output)
            diffLoading = false
        }
    }

    private func copyCommitMessage(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        store.statusMessage = loc("已复制 commit message", "Copied commit message")
    }
}

private struct AgentInboxProjectRow: View {
    let project: AgentInboxProject
    let isSelected: Bool
    let chinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: project.riskLevel.systemImage)
                    .foregroundStyle(color(for: project.riskLevel))
                    .frame(width: 16)
                Text(project.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if project.changedCount > 0 {
                    Text("\(project.changedCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
            Text(project.url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                Label("\(project.sessions.count)", systemImage: "bubble.left.and.bubble.right")
                Label("\(project.recentChanges.count)", systemImage: "plusminus")
                Text(project.riskLevel.title)
                    .foregroundStyle(color(for: project.riskLevel))
                Spacer()
                Text(Self.dateFormatter.string(from: project.latestActivity))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }

    private func color(for level: AgentRiskLevel) -> Color {
        switch level {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}
