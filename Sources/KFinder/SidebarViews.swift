import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var focusedDirectoryID: UUID?
    @State private var workspaceToRename: Workspace?
    @State private var renameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 50)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    workspaceSection
                    bookmarksSection
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .alert("Rename Workspace", isPresented: renameAlertBinding) {
            TextField("Workspace name", text: $renameDraft)
            Button("Cancel", role: .cancel) {
                workspaceToRename = nil
            }
            Button("Rename") {
                if let workspaceToRename {
                    store.renameWorkspace(
                        id: workspaceToRename.id, to: renameDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                workspaceToRename = nil
            }
        }
    }

    private var workspaceSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Workspaces")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.createWorkspace()
                    focusedDirectoryID = store.selectedWorkspace?.directories.first?.id
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("New workspace")
            }
            .padding(.horizontal, 14)

            ForEach(store.workspaces) { workspace in
                WorkspaceSidebarRow(
                    workspace: workspace,
                    isSelected: workspace.id == store.selectedWorkspaceID,
                    select: {
                        store.selectedWorkspaceID = workspace.id
                        focusedDirectoryID = workspace.directories.first?.id
                    },
                    rename: {
                        workspaceToRename = workspace
                        renameDraft = workspace.name
                    },
                    delete: {
                        store.deleteWorkspace(id: workspace.id)
                        focusedDirectoryID = store.selectedWorkspace?.directories.first?.id
                    }
                )
            }
        }
    }

    private var bookmarksSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Bookmarks")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)

            ForEach(store.systemBookmarks) { bookmark in
                Button {
                    focusedDirectoryID = store.openBookmark(bookmark, in: focusedDirectoryID)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: bookmark.systemImage)
                            .frame(width: 22)
                            .foregroundStyle(.blue)
                        Text(bookmark.title)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { workspaceToRename != nil },
            set: { if !$0 { workspaceToRename = nil } }
        )
    }
}

struct WorkspaceSidebarRow: View {
    let workspace: Workspace
    let isSelected: Bool
    let select: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(isSelected ? .blue : .secondary)

            Text(workspace.name)
                .lineLimit(1)

            Spacer()

            Button {
                delete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete workspace")
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            select()
        }
        .contextMenu {
            Button("Rename") {
                rename()
            }
            Button("Delete", role: .destructive) {
                delete()
            }
        }
    }
}
