import SwiftUI

/// Unified view over every Agent Skill scattered across installed AI clients.
/// Left: the aggregated catalog (one row per skill, with agent badges and a
/// drift flag). Right: the selected skill's detail card — purpose, version,
/// and which agents it's active in.
struct SkillHubView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let isSidebarVisible: Bool

    @State private var entries: [SkillEntry] = []
    @State private var isLoading = true
    @State private var selectedID: SkillEntry.ID?

    private var selected: SkillEntry? {
        entries.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(store.loc("技能中心", "Skill Hub"))
                .font(.system(size: 15, weight: .semibold))
            if !isLoading {
                Text("\(entries.count)")
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
            .help(store.loc("重新扫描", "Rescan"))
        }
        .padding(.leading, isSidebarVisible ? 14 : 112)
        .padding(.trailing, 14)
        .frame(height: 44)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entries.isEmpty {
            EmptyStateView(
                title: store.loc("未发现技能", "No skills found"),
                systemImage: "sparkles",
                description: store.loc(
                    "未在已知的 agent 目录中找到 SKILL.md。", "No SKILL.md found in the known agent directories."))
        } else {
            HStack(spacing: 0) {
                skillList.frame(width: 280)
                Divider()
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var skillList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    SkillRow(entry: entry, isSelected: entry.id == selectedID, chinese: chinese)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = entry.id }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if let selected {
            SkillDetailCard(
                entry: selected,
                chinese: chinese,
                store: store,
                onInstall: { agent in
                    guard let source = selected.installations.first(where: { !$0.isReadOnly })?.url else { return }
                    if store.installSkill(from: source, to: agent) {
                        Task { await reload() }
                    }
                },
                onMakeCanonical: { installation in
                    let targets = selected.installations.filter { !$0.isReadOnly }.map(\.url)
                    if store.syncSkill(from: installation.url, to: targets) {
                        Task { await reload() }
                    }
                }
            )
        } else {
            EmptyStateView(
                title: store.loc("选择一个技能", "Select a skill"),
                systemImage: "hand.point.left",
                description: store.loc("点击左侧任意技能查看详情。", "Click a skill on the left to see its details."))
        }
    }

    private var chinese: Bool { store.settings.language.isChineseResolved }

    private func reload() async {
        isLoading = true
        entries = await SkillScanner.scan()
        if selectedID == nil || !entries.contains(where: { $0.id == selectedID }) {
            selectedID = entries.first?.id
        }
        isLoading = false
    }
}

private struct SkillRow: View {
    let entry: SkillEntry
    let isSelected: Bool
    let chinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if entry.hasDrift {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .help(chinese ? "各副本内容不一致" : "Copies differ")
                }
                Spacer(minLength: 4)
            }
            HStack(spacing: 4) {
                ForEach(entry.agents) { agent in
                    Text(agent.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}

private struct SkillDetailCard: View {
    let entry: SkillEntry
    let chinese: Bool
    let store: WorkspaceStore
    let onInstall: (SkillAgent) -> Void
    let onMakeCanonical: (SkillInstallation) -> Void

    private func loc(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    /// Writable agents that don't yet have this skill — distribution targets.
    private var installableAgents: [SkillAgent] {
        let present = Set(entry.agents)
        return SkillAgent.allCases.filter { agent in
            !present.contains(agent) && agent.scanDirectories.contains { !$0.isReadOnly }
        }
    }

    private var hasWritableCopy: Bool {
        entry.installations.contains { !$0.isReadOnly }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 20, weight: .semibold))
                        .textSelection(.enabled)
                    HStack(spacing: 8) {
                        metaChip(
                            label: loc("版本", "Version"),
                            value: entry.version ?? loc("未标注", "unspecified"))
                        if let license = entry.license {
                            metaChip(label: loc("许可", "License"), value: license)
                        }
                        if entry.hasDrift {
                            Label(loc("副本不一致", "Copies differ"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                section(loc("用途", "Purpose")) {
                    Text(entry.description.isEmpty ? loc("（无描述）", "(no description)") : entry.description)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.description.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section(loc("在以下 agent 生效", "Active in")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.installations) { installation in
                            installationRow(installation)
                        }
                    }
                }

                if entry.hasDrift, hasWritableCopy {
                    Text(
                        loc(
                            "各副本内容不一致。展开上方某个副本旁的「设为基准」可用它覆盖其它可写副本。",
                            "Copies differ. Use “Make canonical” on a copy above to overwrite the other writable copies."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                if !installableAgents.isEmpty, hasWritableCopy {
                    section(loc("分发到", "Distribute to")) {
                        HStack(spacing: 8) {
                            ForEach(installableAgents) { agent in
                                Button {
                                    onInstall(agent)
                                } label: {
                                    Label(agent.displayName, systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func installationRow(_ installation: SkillInstallation) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(installation.agent.displayName)
                        .font(.system(size: 13, weight: .medium))
                    if installation.isReadOnly {
                        Text(loc("内置·只读", "built-in · read-only"))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(installation.url.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 6)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([installation.url])
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(loc("在 Finder 中显示", "Reveal in Finder"))

            Button {
                NSWorkspace.shared.open(installation.url.appendingPathComponent("SKILL.md"))
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(loc("编辑 SKILL.md", "Edit SKILL.md"))

            // Resolve drift: overwrite the other writable copies with this one.
            if entry.hasDrift, !installation.isReadOnly {
                Button {
                    onMakeCanonical(installation)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help(loc("设为基准并覆盖其它副本", "Make canonical (overwrite other copies)"))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }

    private func metaChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value).foregroundStyle(.primary)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
