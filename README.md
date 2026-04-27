# KFinder

KFinder is a macOS multi-pane file manager built for a personal workflow: viewing, comparing, copying, moving, renaming, and organizing files across several directories at the same time.

KFinder 是一个 macOS 多面板文件管理工具，主要服务于个人工作流：在多个目录之间同时查看、对比、复制、移动、重命名和整理文件。

The project started from a simple need: Finder is great for one folder at a time, but day-to-day work often involves multiple active directories. KFinder keeps those folders visible in one workspace so file management can happen without constantly switching Finder windows.

这个项目来自一个很具体的需求：Finder 很适合单个目录的管理，但日常工作里经常需要同时处理多个目录。KFinder 希望把这些目录放进同一个工作区，减少在多个 Finder 窗口之间来回切换。

This tool was designed and implemented with help from an LLM. The goal is not to replace Finder completely, but to create a focused, personal file management workspace that feels close to native macOS behavior where it matters.

这个工具是在 LLM 的辅助下设计和实现的。它并不试图完整替代 Finder，而是希望在关键交互上尽量贴近 macOS 原生体验，同时聚焦于多目录文件管理这个个人场景。

## What KFinder Does

- Groups multiple folders into one workspace.
- Shows folders as multiple file-management panes in one window.
- Lets each pane navigate independently with back, forward, parent-folder, and breadcrumb controls.
- Supports list, icon, and column-style pane views.
- Supports two-column, three-column, grid, and main-plus-stack workspace layouts.
- Provides Finder-style bookmarks such as Desktop, Downloads, Documents, Applications, Trash, iCloud Drive, and Macintosh HD.
- Opens files and `.app` bundles through macOS.
- Supports inline rename after selecting a file and clicking its name.
- Supports moving files by dragging them into another pane.
- Supports context-menu copy/move to another pane's current path.
- Supports moving files to Trash.
- Supports sorting by modified date and kind.
- Supports adaptive/resizable list columns for Name, Modified, Size, and Kind.
- Can reveal files or folders in native Finder.
- Can import currently open Finder windows as KFinder panes.

## 功能说明

- 将多个文件夹组织到同一个工作区。
- 在一个窗口内以多个文件管理面板展示不同目录。
- 每个面板都可以独立前进、后退、返回上级目录，并通过面包屑路径导航。
- 支持列表、图标和类 Column View 的展示方式。
- 支持双列、三列、网格、主面板加堆叠等工作区布局。
- 提供类似 Finder 的系统书签，如桌面、下载、文稿、应用程序、废纸篓、iCloud Drive 和 Macintosh HD。
- 通过 macOS 打开文件和 `.app` 应用包。
- 支持选中文件后再次点击文件名进行内联重命名。
- 支持将文件拖拽移动到另一个面板。
- 支持通过右键菜单复制或移动文件到其它面板当前所在路径。
- 支持移动文件到废纸篓。
- 支持按修改日期和文件种类排序。
- 支持 Name、Modified、Size、Kind 列的自适应和宽度调整。
- 支持在原生 Finder 中显示文件或文件夹。
- 支持将当前已打开的 Finder 窗口导入为 KFinder 面板。

## Why Not Embed Finder?

macOS does not provide a stable public API for embedding native Finder windows inside another app. KFinder therefore implements its own file browser UI with SwiftUI/AppKit and uses Finder only for optional system integrations such as reveal and importing open Finder window paths.

## 为什么不直接嵌入 Finder？

macOS 没有提供稳定的公开 API，可以把原生 Finder 窗口直接嵌入到另一个应用里。因此 KFinder 使用 SwiftUI/AppKit 自己实现文件浏览界面，只在“在 Finder 中显示”和“导入当前 Finder 窗口路径”等场景中调用系统 Finder 能力。

## Architecture

KFinder is a Swift Package Manager macOS app with a SwiftUI interface and selected AppKit integrations.

KFinder 是一个基于 Swift Package Manager 的 macOS 应用，主要界面使用 SwiftUI 实现，并在窗口控制、Finder 集成、文件操作等位置使用 AppKit 能力。

Key modules:

- `KFinderApp.swift`: app entry point and scene setup.
- `ContentView.swift`: top-level shell, sidebar/content split, global state wiring.
- `SidebarViews.swift`: workspace list, system bookmarks, sidebar interactions.
- `WorkspaceViews.swift`: top toolbar, layout picker, multi-pane workspace layout.
- `BrowserPaneView.swift`: pane navigation, file loading, sorting, rename state, drag/drop, breadcrumbs.
- `FileItemViews.swift`: list rows, icon cells, column rows, selection and rename UI.
- `WorkspaceStore.swift`: workspace persistence, pane locations, file operations, Finder import.
- `FileBrowserService.swift`: file-system listing and metadata extraction.
- `FinderController.swift`: AppleScript bridge for reading open Finder window paths.
- `SharedViews.swift`: window chrome and AppKit helper views.

主要模块：

- `KFinderApp.swift`：应用入口和窗口场景配置。
- `ContentView.swift`：顶层界面结构，负责侧边栏和主内容区的组合。
- `SidebarViews.swift`：工作区列表、系统书签和侧边栏交互。
- `WorkspaceViews.swift`：顶部工具栏、布局选择和多面板布局。
- `BrowserPaneView.swift`：单个文件管理面板的导航、文件加载、排序、重命名、拖放和路径面包屑。
- `FileItemViews.swift`：文件行、图标单元格、Column 行、选中态和重命名 UI。
- `WorkspaceStore.swift`：工作区持久化、面板路径、文件操作和 Finder 导入。
- `FileBrowserService.swift`：文件系统列表读取和元数据提取。
- `FinderController.swift`：通过 AppleScript 读取当前打开的 Finder 窗口路径。
- `SharedViews.swift`：窗口样式和 AppKit 辅助视图。

Build and release scripts:

- `scripts/build-app.sh`: builds `dist/KFinder.app`.
- `scripts/release.sh`: builds, ad-hoc signs, zips, and generates SHA-256 checksums.
- `.github/workflows/release.yml`: creates a GitHub Release when a `v*` tag is pushed.

构建和发布脚本：

- `scripts/build-app.sh`：构建 `dist/KFinder.app`。
- `scripts/release.sh`：构建、ad-hoc 签名、压缩，并生成 SHA-256 校验文件。
- `.github/workflows/release.yml`：当推送 `v*` tag 时自动创建 GitHub Release。

## Download From GitHub Releases

Download the latest `KFinder-*-macOS-*.zip` from the repository's Releases page, unzip it, then move `KFinder.app` to `/Applications`.

从仓库的 Releases 页面下载最新的 `KFinder-*-macOS-*.zip`，解压后将 `KFinder.app` 移动到 `/Applications`。

Current test builds use ad-hoc signing. On first launch, macOS may block the app because it is not Developer ID signed or notarized yet. If that happens:

当前测试版本使用 ad-hoc 签名。首次打开时，macOS 可能会因为应用尚未使用 Developer ID 签名和公证而拦截。如果出现这种情况：

1. Right-click `KFinder.app`.
2. Choose `Open`.
3. Confirm the system prompt.

1. 右键点击 `KFinder.app`。
2. 选择“打开”。
3. 在系统提示中确认打开。

When using `Import Finder Windows`, macOS may ask for Automation permission so KFinder can read the paths of currently open Finder windows.

使用 `Import Finder Windows` 时，macOS 可能会请求自动化权限，用于读取当前已打开 Finder 窗口的路径。

## Run From Source

```bash
swift run KFinder
```

## 从源码运行

```bash
swift run KFinder
```

## Build a macOS App Bundle

```bash
./scripts/build-app.sh
open dist/KFinder.app
```

## 构建 macOS 应用包

```bash
./scripts/build-app.sh
open dist/KFinder.app
```

## Build a GitHub Release Artifact

```bash
./scripts/release.sh
```

This creates:

- `release/KFinder-<version>-macOS-<arch>.zip`
- `release/KFinder-<version>-macOS-<arch>.zip.sha256`

The release artifact is ad-hoc signed for test distribution. For public distribution, use Developer ID signing and Apple notarization.

## 构建 GitHub Release 产物

```bash
./scripts/release.sh
```

会生成：

- `release/KFinder-<version>-macOS-<arch>.zip`
- `release/KFinder-<version>-macOS-<arch>.zip.sha256`

当前 Release 产物使用 ad-hoc 签名，适合测试分发。如果要公开分发，建议使用 Developer ID 签名并完成 Apple 公证。

## Publish With GitHub Releases

After pushing the project to GitHub, create and push a version tag:

```bash
git tag v0.1.0
git push origin main --tags
```

GitHub Actions will build the app, create a Release, and upload the zip plus checksum.

## 通过 GitHub Releases 发布

将项目推送到 GitHub 后，创建并推送版本 tag：

```bash
git tag v0.1.0
git push origin main --tags
```

GitHub Actions 会自动构建应用、创建 Release，并上传 zip 包和 checksum 文件。

## Current Limitations

- Not Developer ID signed or notarized yet.
- Current packaged build is arm64-focused.
- File operations are intentionally simple; advanced conflict resolution is limited.
- No file-system watcher yet, so external changes may require refresh/navigation to appear.
- No full Finder feature parity: tags, smart folders, server browsing, advanced preview, sidebar customization, and rich metadata editing are not implemented.
- Drag/drop is focused on moving files between KFinder panes.
- No automated test suite yet.

## 当前局限

- 尚未使用 Developer ID 签名，也尚未完成 Apple 公证。
- 当前打包版本主要面向 Apple Silicon Mac。
- 文件操作仍然比较基础，复杂冲突处理能力有限。
- 暂未实现文件系统监听，因此外部变化可能需要刷新或重新进入目录后才能出现。
- 不追求完整 Finder 对齐，尚未支持标签、智能文件夹、服务器浏览、高级预览、侧边栏自定义和丰富元数据编辑等能力。
- 拖拽能力主要聚焦于 KFinder 面板之间的文件移动。
- 暂未建立自动化测试。

## Thanks

Thanks to [QSpace](https://qspace.awehunt.com/zh-cn/index.html#). KFinder referenced and learned from some of QSpace's product and interaction design during exploration. If you need a mature and stable multi-pane file manager, QSpace is recommended.

## 感谢

感谢 [QSpace](https://qspace.awehunt.com/zh-cn/index.html#)。KFinder 在设计探索过程中参考和借鉴了 QSpace 的部分产品与交互设计。如果你需要成熟稳定的多面板文件管理工具，推荐优先使用 QSpace。

## Project Status

KFinder is currently a usable personal tool and a GitHub-ready early release. It is suitable for experimentation and small-scope personal use, but should still be treated as an early-stage macOS file manager.

## 项目状态

KFinder 目前是一个基本可用的个人工具，也已经具备上传 GitHub 和进行早期分发的基础。它适合实验和小范围个人使用，但仍应被视为早期阶段的 macOS 文件管理工具。

## License

KFinder is released under the MIT License. See `LICENSE` for details.

## 许可证

KFinder 使用 MIT License 发布，详情见 `LICENSE` 文件。
