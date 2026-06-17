import SwiftUI

/// App settings sheet (opened from the sidebar gear): language, opt-in Claude
/// integration + CLI path, Debug mode, and the What's New entry. All strings
/// are bilingual via `store.loc`.
struct SettingsView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let onClose: () -> Void
    @State private var showsWhatsNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(store.loc("设置", "Settings"), systemImage: "gearshape")
                    .font(.headline)
                Spacer()
                Button(store.loc("完成", "Done")) { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    languageSection
                    Divider()
                    claudeSection
                    Divider()
                    debugSection
                    Divider()
                    aboutSection
                }
                .padding(18)
            }
        }
        .frame(width: 520, height: 480)
        .sheet(isPresented: $showsWhatsNew) {
            WhatsNewSheet(onClose: { showsWhatsNew = false })
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.loc("语言", "Language"))
                .font(.system(size: 13, weight: .semibold))
            Picker("", selection: languageBinding) {
                Text(store.loc("跟随系统", "System")).tag(AppLanguage.system)
                Text("中文").tag(AppLanguage.chinese)
                Text("English").tag(AppLanguage.english)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var claudeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.loc("Claude 集成", "Claude integration"))
                .font(.system(size: 13, weight: .semibold))

            Toggle(isOn: claudeEnabledBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.loc("启用 Claude 集成", "Enable Claude integration"))
                    Text(
                        store.loc(
                            "在面板右键菜单和项目状态卡片中显示 Analyze / Ask / Open in Claude Code。默认关闭。",
                            "Show Analyze / Ask / Open in Claude Code in pane menus and the project status card. Off by default."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if store.settings.claudeIntegrationEnabled {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.loc("claude CLI 路径", "claude CLI path"))
                        .font(.system(size: 12, weight: .medium))
                    TextField(
                        store.loc(
                            "留空则用登录 shell 的 PATH 解析 claude", "Leave empty to resolve claude via the login shell PATH"),
                        text: cliPathBinding
                    )
                    .textFieldStyle(.roundedBorder)
                    Text(
                        store.loc(
                            "仅当 claude 不在 PATH 中时才需要填写绝对路径，例如 /opt/homebrew/bin/claude。",
                            "Only needed when claude isn't on PATH, e.g. /opt/homebrew/bin/claude."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Text(
                store.loc(
                    "XFinder 不存储任何 API key —— 它复用你本机已安装、已登录的 Claude Code CLI。",
                    "XFinder stores no API key — it reuses the Claude Code CLI already installed and signed in on your Mac."
                )
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.loc("调试", "Debug"))
                .font(.system(size: 13, weight: .semibold))
            Toggle(isOn: debugBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.loc("开启 Debug 模式", "Enable Debug mode"))
                    Text(
                        store.loc(
                            "在顶部工具栏显示「操作与错误记录」面板，便于排查问题。默认关闭。",
                            "Show the Activity & Errors panel in the top toolbar for troubleshooting. Off by default."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.loc("关于", "About"))
                .font(.system(size: 13, weight: .semibold))
            Button {
                showsWhatsNew = true
            } label: {
                Label(store.loc("更新日志 / What's New", "What's New"), systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { store.settings.language }, set: { store.settings.language = $0 })
    }

    private var debugBinding: Binding<Bool> {
        Binding(get: { store.settings.debugModeEnabled }, set: { store.settings.debugModeEnabled = $0 })
    }

    private var claudeEnabledBinding: Binding<Bool> {
        Binding(get: { store.settings.claudeIntegrationEnabled }, set: { store.settings.claudeIntegrationEnabled = $0 })
    }

    private var cliPathBinding: Binding<String> {
        Binding(get: { store.settings.claudeCLIPath }, set: { store.settings.claudeCLIPath = $0 })
    }
}
