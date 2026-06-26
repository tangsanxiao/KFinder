import SwiftUI

struct FileInfoSheet: View {
    let snapshot: FileInfoSnapshot
    let chinese: Bool
    let onReveal: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                FileIconView(url: snapshot.url, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(snapshot.kind)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(chinese ? "关闭" : "Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            VStack(spacing: 8) {
                infoRow(chinese ? "位置" : "Where", snapshot.path)
                infoRow(chinese ? "大小" : "Size", snapshot.size.map(DisplayFormatters.size) ?? "--")
                infoRow(chinese ? "创建时间" : "Created", DisplayFormatters.date(snapshot.created))
                infoRow(chinese ? "修改时间" : "Modified", DisplayFormatters.date(snapshot.modified))
                infoRow(chinese ? "权限" : "Permissions", snapshot.posixPermissions)
                infoRow(chinese ? "所有者" : "Owner", "\(snapshot.owner):\(snapshot.group)")
                infoRow(chinese ? "访问" : "Access", snapshot.access)
                infoRow(chinese ? "隐藏" : "Hidden", snapshot.isHidden ? (chinese ? "是" : "Yes") : (chinese ? "否" : "No"))
                infoRow(
                    chinese ? "包" : "Package", snapshot.isPackage ? (chinese ? "是" : "Yes") : (chinese ? "否" : "No"))
            }

            Divider()

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snapshot.path, forType: .string)
                } label: {
                    Label(chinese ? "复制路径" : "Copy Path", systemImage: "doc.on.doc")
                }

                Button(action: onReveal) {
                    Label(chinese ? "在 Finder 中显示" : "Reveal in Finder", systemImage: "arrow.up.forward.app")
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 13))
    }
}
