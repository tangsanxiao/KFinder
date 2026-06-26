import SwiftUI

struct FileSearchSheet: View {
    let root: URL
    @Binding var query: String
    let results: [FileSearchResult]
    let isSearching: Bool
    let errorText: String?
    let chinese: Bool
    let onSearch: () -> Void
    let onOpen: (URL) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(chinese ? "搜索文件夹" : "Search Folder", systemImage: "magnifyingglass")
                    .font(.headline)
                Spacer()
                Button(chinese ? "关闭" : "Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }

            Text(root.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 8) {
                TextField(chinese ? "输入文件名或路径片段" : "File name or path contains…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(onSearch)
                Button(chinese ? "搜索" : "Search") { onSearch() }
                    .keyboardShortcut(.defaultAction)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(chinese ? "正在递归搜索…" : "Searching recursively…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else if results.isEmpty {
                EmptyStateView(
                    title: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? (chinese ? "输入关键词开始搜索" : "Type to search")
                        : (chinese ? "没有匹配结果" : "No matches"),
                    systemImage: "magnifyingglass",
                    description: chinese ? "搜索会递归扫描当前面板所在目录。" : "Search scans the focused pane's folder recursively."
                )
                .frame(minHeight: 260)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { result in
                            Button {
                                onOpen(result.url)
                            } label: {
                                SearchResultRow(result: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minHeight: 320)
            }
        }
        .padding(20)
        .frame(width: 680)
        .frame(minHeight: 430)
    }
}

private struct SearchResultRow: View {
    let result: FileSearchResult

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: result.url, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(DisplayFormatters.date(result.modificationDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(result.relativePath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(result.kind)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
