import SwiftUI

struct FileTaskOverlay: View {
    @EnvironmentObject private var store: WorkspaceStore

    var body: some View {
        if !store.fileTasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.fileTasks) { task in
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(task.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 10)
                        if task.isCancellable {
                            Button {
                                store.cancelFileTask(id: task.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .helpTip(store.loc("取消任务", "Cancel task"))
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.5))
                    }
                }
            }
            .frame(width: 300)
            .padding(14)
        }
    }
}
