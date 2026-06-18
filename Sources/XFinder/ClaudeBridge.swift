import Foundation

/// Bridges a pane's directory to the locally installed Claude Code CLI — the
/// "agent 桥接" path. No API keys are managed here on purpose: the CLI already
/// owns auth, tools, and project context; XFinder just invokes it headless.
enum ClaudeBridge {
    static let analysisPrompt = """
        用中文简要总结这个项目的当前状态：\
        1) 这是什么项目；\
        2) 最近在做什么（参考 git log、CHANGELOG.md、AI_CONTEXT.md、README）；\
        3) 有哪些未提交的改动。\
        300 字以内，直接给结论，不要列工具调用过程。
        """

    enum BridgeError: LocalizedError {
        case nonZeroExit(Int32, String)

        var errorDescription: String? {
            switch self {
            case .nonZeroExit(let code, let stderr):
                let detail = stderr.isEmpty ? "请确认已安装 claude CLI（命令行运行 claude --version 检查）" : stderr
                return "claude 退出码 \(code)：\(detail)"
            }
        }
    }

    /// Prompt for explaining a specific change, with the diff inlined so Claude
    /// reasons about the actual edit rather than re-scanning the project.
    static func explainDiffPrompt(fileName: String, diff: String) -> String {
        """
        用中文解释下面这个文件「\(fileName)」的本次改动：\
        1) 改了什么；2) 为什么可能这么改 / 意图；3) 有没有需要注意的风险或副作用。\
        200 字以内，直接给结论。以下是 git diff：

        \(diff)
        """
    }

    /// Prompt prefix for "ask about these files" — relative paths follow.
    static func selectionPrompt(for paths: [String]) -> String {
        "简要说明下列文件/文件夹的内容、用途和当前状态（如有 git 改动一并说明），中文回答：\n"
            + paths.map { "- " + $0 }.joined(separator: "\n")
    }

    /// The CLI invocation token: a custom absolute path (quoted) or bare
    /// `claude` resolved via the login shell's PATH.
    static func cliCommand(path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "claude" : shellQuoted(trimmed)
    }

    /// Runs `claude -p <prompt>` in `directory` and returns its stdout.
    /// Goes through a login shell so the user's PATH resolves the CLI; the
    /// child process is terminated if the surrounding task is cancelled.
    static func analyzeProject(
        at directory: URL, prompt: String = analysisPrompt, cliPath: String = ""
    ) async throws
        -> String
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.currentDirectoryURL = directory
        process.arguments = ["-lc", cliCommand(path: cliPath) + " -p " + shellQuoted(prompt)]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) { () -> String in
                try process.run()
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw BridgeError.nonZeroExit(
                        process.terminationStatus,
                        String(data: errData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                }
                return String(data: outData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }.value
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    /// Single-quotes a string for safe interpolation into a zsh command line.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
