import SwiftUI

/// Minimal line-based markdown model for the bundled CHANGELOG — enough for
/// headings and bullets, no external dependency. Pure and unit-tested.
enum ChangelogParser {
    struct Line: Identifiable, Equatable {
        enum Kind: Equatable {
            case heading1
            case heading2
            case heading3
            case bullet(indent: Int)
            case text
        }

        let id: Int
        let kind: Kind
        let content: String
    }

    static func parse(_ markdown: String) -> [Line] {
        markdown.components(separatedBy: "\n").enumerated().compactMap { index, rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            if line.hasPrefix("### ") {
                return Line(id: index, kind: .heading3, content: String(line.dropFirst(4)))
            }
            if line.hasPrefix("## ") {
                return Line(id: index, kind: .heading2, content: String(line.dropFirst(3)))
            }
            if line.hasPrefix("# ") {
                return Line(id: index, kind: .heading1, content: String(line.dropFirst(2)))
            }
            if line.hasPrefix("- ") {
                let leadingSpaces = rawLine.prefix(while: { $0 == " " }).count
                return Line(id: index, kind: .bullet(indent: leadingSpaces / 2), content: String(line.dropFirst(2)))
            }
            return Line(id: index, kind: .text, content: line)
        }
    }

    /// The bundled changelog (copied in by build-app.sh). Nil in dev runs
    /// without packaging.
    static func bundledChangelog() -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

/// "What's New" sheet — renders the bundled CHANGELOG so the app itself can
/// answer "这个 app 有哪些功能、最近改了什么" after time away from the project.
struct WhatsNewSheet: View {
    let onClose: () -> Void
    private let lines: [ChangelogParser.Line]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        lines = ChangelogParser.parse(ChangelogParser.bundledChangelog() ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("What's New", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            if lines.isEmpty {
                Text("未找到打包的 CHANGELOG（开发模式下用 build-app.sh 打包后可见）。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(lines) { line in
                            lineView(line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, 8)
                }
                .frame(minHeight: 240, maxHeight: 460)
            }
        }
        .padding(18)
        .frame(width: 620)
    }

    @ViewBuilder
    private func lineView(_ line: ChangelogParser.Line) -> some View {
        switch line.kind {
        case .heading1:
            Text(line.content)
                .font(.title3.weight(.bold))
                .padding(.top, 2)
        case .heading2:
            Text(line.content)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 8)
        case .heading3:
            Text(line.content)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        case .bullet(let indent):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text(line.content)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indent) * 14)
        case .text:
            Text(line.content)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

/// Trace panel popover: timestamped status messages and errors from the
/// store, newest first — so "哪里出错了" has a real answer instead of one
/// vanished alert.
struct EventLogPanel: View {
    let events: [AppEvent]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity & Errors")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { onClear() }
                    .controlSize(.small)
                    .disabled(events.isEmpty)
            }

            if events.isEmpty {
                Text("还没有记录。文件操作和错误都会出现在这里。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(events) { event in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(Self.timeFormatter.string(from: event.date))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Image(systemName: event.isError ? "xmark.octagon.fill" : "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(event.isError ? Color.red : Color.secondary)
                                Text(event.message)
                                    .font(.system(size: 12))
                                    .foregroundStyle(event.isError ? Color.primary : Color.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(12)
        .frame(width: 420)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
