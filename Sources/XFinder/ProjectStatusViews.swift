import SwiftUI

/// Popover card summarizing the git repo a pane is sitting in: branch,
/// uncommitted-change count, recent commits, plus the agent-bridge actions.
struct ProjectStatusCard: View {
    let snapshot: GitDirectorySnapshot
    let claudeEnabled: Bool
    let onAnalyze: () -> Void
    let onOpenClaudeCode: () -> Void
    let onOpenTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                Text(snapshot.branch)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if snapshot.changedPathCount > 0 {
                    Text("\(snapshot.changedPathCount) 处未提交")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                } else {
                    Text("工作区干净")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if !snapshot.recentCommits.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(snapshot.recentCommits) { commit in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(commit.id)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(commit.subject)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(commit.relativeDate)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                if claudeEnabled {
                    Button {
                        onAnalyze()
                    } label: {
                        Label("Analyze with Claude", systemImage: "sparkles")
                    }
                    Button {
                        onOpenClaudeCode()
                    } label: {
                        Label("Open in Claude Code", systemImage: "apple.terminal")
                    }
                }
                Button {
                    onOpenTerminal()
                } label: {
                    Label("Terminal", systemImage: "terminal")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 380)
    }
}

/// Sheet for headless `claude -p` runs against the pane's directory. The
/// question is always visible and editable, so any entry point (preset
/// analysis, free-form ask, selection ask) becomes a re-runnable conversation
/// starter.
struct ClaudeAnalysisSheet: View {
    let directoryName: String
    @Binding var question: String
    let isRunning: Bool
    let resultText: String?
    let errorText: String?
    let onRun: () -> Void
    let onClose: () -> Void
    @FocusState private var questionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ask Claude — \(directoryName)", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("想了解这个目录的什么？", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...6)
                    .focused($questionFocused)
                    .onSubmit { runIfPossible() }
                Button {
                    runIfPossible()
                } label: {
                    Label(resultText == nil ? "Run" : "Re-run", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRunning || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            if isRunning {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Claude 正在阅读这个目录…（关闭窗口可取消）")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            } else if let resultText {
                ScrollView {
                    Text(resultText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 100, maxHeight: 360)

                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(resultText, forType: .string)
                    } label: {
                        Label("Copy Result", systemImage: "doc.on.doc")
                    }
                    .controlSize(.small)
                }
            } else {
                Text("输入问题后点 Run。Claude 会在这个目录里用完整 agent 能力作答（可读文件、跑 git）。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .onAppear { questionFocused = true }
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private func runIfPossible() {
        guard !isRunning, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onRun()
    }
}
