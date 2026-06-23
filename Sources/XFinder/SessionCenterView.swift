import SwiftUI

/// Unified view over chat sessions from every code agent (Claude, Codex).
/// Left: a filterable list (project, date, ~tokens). Right: the transcript and
/// summaries (instant deterministic, or via the configured third-party LLM).
struct SessionCenterView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let isSidebarVisible: Bool

    @State private var sessions: [SessionSummary] = []
    @State private var isLoading = true
    @State private var selectedID: SessionSummary.ID?
    @State private var agentFilter: SessionAgent?
    @State private var query = ""

    @State private var transcript: SessionTranscript?
    @State private var transcriptLoading = false
    @State private var summaryText: String?
    @State private var summaryRunning = false
    @State private var summaryError: String?
    @State private var summaryTask: Task<Void, Never>?

    private var chinese: Bool { store.settings.language.isChineseResolved }
    private func loc(_ zh: String, _ en: String) -> String { store.loc(zh, en) }

    private var selected: SessionSummary? { sessions.first { $0.id == selectedID } }

    private var presentAgents: [SessionAgent] {
        SessionAgent.allCases.filter { agent in sessions.contains { $0.agent == agent } }
    }

    private var filtered: [SessionSummary] {
        sessions.filter { session in
            if let agentFilter, session.agent != agentFilter { return false }
            let q = query.trimmingCharacters(in: .whitespaces)
            if !q.isEmpty {
                return session.title.localizedCaseInsensitiveContains(q)
                    || session.project.localizedCaseInsensitiveContains(q)
            }
            return true
        }
    }

    private var totalTokens: Int { sessions.reduce(0) { $0 + $1.approxTokens } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !isLoading, !sessions.isEmpty {
                filterBar
                Divider()
            }
            content
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(loc("会话中心", "Session Center"))
                .font(.system(size: 15, weight: .semibold))
            if !isLoading {
                Text(
                    loc(
                        "\(sessions.count) 个会话 · ≈\(formatted(totalTokens)) tokens",
                        "\(sessions.count) sessions · ≈\(formatted(totalTokens)) tokens")
                )
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
            .help(loc("重新扫描", "Rescan"))
        }
        .padding(.leading, isSidebarVisible ? 14 : 112)
        .padding(.trailing, 14)
        .frame(height: 44)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            chip(loc("全部", "All"), active: agentFilter == nil) { agentFilter = nil }
            ForEach(presentAgents) { agent in
                chip(agent.displayName, active: agentFilter == agent) {
                    agentFilter = agentFilter == agent ? nil : agent
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField(loc("搜索标题/项目", "Search title / project"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 180)
            }
        }
        .padding(.horizontal, isSidebarVisible ? 14 : 18)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if sessions.isEmpty {
            EmptyStateView(
                title: loc("未发现会话", "No sessions found"),
                systemImage: "bubble.left.and.bubble.right",
                description: loc("未在已知 agent 的会话目录中找到记录。", "No transcripts in the known agent session directories."))
        } else {
            HStack(spacing: 0) {
                list.frame(width: 320)
                Divider()
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Sessions grouped by project folder, groups ordered by their most-recent
    /// session (so the project you touched last is on top).
    private var groupedByProject: [(project: String, sessions: [SessionSummary])] {
        var groups: [String: [SessionSummary]] = [:]
        var order: [String] = []
        for session in filtered {
            if groups[session.project] == nil { order.append(session.project) }
            groups[session.project, default: []].append(session)
        }
        return order.map { (project: $0, sessions: groups[$0]!) }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByProject, id: \.project) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            SessionRow(session: session, isSelected: session.id == selectedID, chinese: chinese)
                                .contentShape(Rectangle())
                                .onTapGesture { select(session) }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder").font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(group.project).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                            Text("\(group.sessions.count)").font(.system(size: 10)).foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let selected {
            SessionDetailView(
                session: selected,
                transcript: transcript,
                transcriptLoading: transcriptLoading,
                summaryText: summaryText,
                summaryRunning: summaryRunning,
                summaryError: summaryError,
                llmConfigured: store.settings.summaryLLM.isUsable,
                chinese: chinese,
                onQuickSummary: { quickSummary() },
                onLLMSummary: { llmSummary() },
                onReveal: { NSWorkspace.shared.activateFileViewerSelecting([selected.url]) }
            )
        } else {
            EmptyStateView(
                title: loc("选择一个会话", "Select a session"),
                systemImage: "hand.point.left",
                description: loc("点击左侧任意会话查看历史与摘要。", "Click a session to view its history and summary."))
        }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.12)))
                .foregroundStyle(active ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func select(_ session: SessionSummary) {
        selectedID = session.id
        transcript = nil
        summaryText = nil
        summaryError = nil
        summaryTask?.cancel()
        transcriptLoading = true
        Task {
            let loaded = await SessionScanner.transcript(for: session.url)
            guard selectedID == session.id else { return }
            transcript = loaded
            transcriptLoading = false
        }
    }

    /// Instant, deterministic recap from the transcript — no LLM.
    private func quickSummary() {
        guard let transcript else { return }
        let users = transcript.messages.filter { $0.role == .user }
        let first = users.first?.text ?? ""
        let last = users.count > 1 ? users.last?.text ?? "" : ""
        var parts = [
            loc(
                "共 \(transcript.messages.count) 条消息,≈\(formatted(transcript.exactTokens)) tokens。",
                "\(transcript.messages.count) messages, ≈\(formatted(transcript.exactTokens)) tokens.")
        ]
        if !first.isEmpty { parts.append(loc("开始:", "Start: ") + oneLine(first)) }
        if !last.isEmpty { parts.append(loc("最后:", "Last: ") + oneLine(last)) }
        summaryError = nil
        summaryText = parts.joined(separator: "\n\n")
    }

    private func llmSummary() {
        guard let transcript else { return }
        summaryError = nil
        summaryRunning = true
        summaryText = nil
        // Cap the payload so a huge transcript doesn't blow the context/cost.
        let joined = transcript.messages.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")
        let capped = String(joined.prefix(16000))
        let config = store.settings.summaryLLM
        summaryTask = Task {
            do {
                let result = try await SummaryLLMClient.summarize(text: capped, config: config)
                summaryText = result
            } catch is CancellationError {
            } catch {
                summaryError = error.localizedDescription
            }
            summaryRunning = false
        }
    }

    private func oneLine(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > 100 ? String(flat.prefix(100)) + "…" : flat
    }

    private func formatted(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.0fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func reload() async {
        isLoading = true
        sessions = await SessionScanner.scan()
        if selectedID == nil || !sessions.contains(where: { $0.id == selectedID }) {
            selectedID = nil
        }
        isLoading = false
    }
}

private struct SessionRow: View {
    let session: SessionSummary
    let isSelected: Bool
    let chinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(session.agent.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
                Text(Self.dateFormatter.string(from: session.modified))
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                Text("≈\(session.approxTokens / 1000)k").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

private struct SessionDetailView: View {
    let session: SessionSummary
    let transcript: SessionTranscript?
    let transcriptLoading: Bool
    let summaryText: String?
    let summaryRunning: Bool
    let summaryError: String?
    let llmConfigured: Bool
    let chinese: Bool
    let onQuickSummary: () -> Void
    let onLLMSummary: () -> Void
    let onReveal: () -> Void

    private func loc(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title).font(.system(size: 16, weight: .semibold)).lineLimit(2).textSelection(.enabled)
                HStack(spacing: 10) {
                    Label(session.agent.displayName, systemImage: "cpu").font(.system(size: 11)).foregroundStyle(
                        .secondary)
                    Label(session.project, systemImage: "folder").font(.system(size: 11)).foregroundStyle(.secondary)
                    Button {
                        onReveal()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help(loc("在 Finder 中显示", "Reveal in Finder"))
                }
                summaryBar
            }
            .padding(16)
            Divider()
            transcriptView
        }
    }

    private var summaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    onQuickSummary()
                } label: {
                    Label(loc("快速摘要", "Quick summary"), systemImage: "text.alignleft")
                }
                .controlSize(.small).disabled(transcript == nil)
                Button {
                    onLLMSummary()
                } label: {
                    Label(loc("用 LLM 总结", "Summarize with LLM"), systemImage: "sparkles")
                }
                .controlSize(.small).disabled(transcript == nil || !llmConfigured || summaryRunning)
                if !llmConfigured {
                    Text(loc("（在设置中配置 LLM 后可用）", "(configure an LLM in Settings)"))
                        .font(.caption).foregroundStyle(.tertiary)
                }
                if summaryRunning { ProgressView().controlSize(.small) }
            }
            .buttonStyle(.bordered)

            if let summaryError {
                Text(summaryError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            } else if let summaryText {
                ScrollView {
                    Text(summaryText).font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }
        }
    }

    @ViewBuilder
    private var transcriptView: some View {
        if transcriptLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let transcript {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(transcript.messages) { message in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(message.role == .user ? loc("用户", "User") : "Assistant")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(message.role == .user ? Color.accentColor : Color.secondary)
                            Text(message.text)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    message.role == .user
                                        ? Color.accentColor.opacity(0.06) : Color.secondary.opacity(0.06))
                        )
                    }
                }
                .padding(16)
            }
        } else {
            Color.clear
        }
    }
}
