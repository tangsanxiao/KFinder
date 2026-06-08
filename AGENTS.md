# AGENTS.md — XFinder 项目协作规则

> 给所有在本仓库工作的 AI/人。每条都是踩过的坑的根因（情况 → 要求 → 原因）。

## 构建与打包

- **情况**：`scripts/build-app.sh` 用 `set -euo pipefail`，里面的 `git describe --tags --exact-match` 在 HEAD 没有精确 tag 时返回 128。
  **要求**：脚本里每个可能失败的 `git` 调用都要以 `|| true` 收尾（即使有 `2>/dev/null`）。
  **原因**：`2>/dev/null` 只藏住报错信息，`set -e`/`pipefail` 仍会让整个脚本在算版本号那步中止，`swift build` 根本不执行，dist 静默保留旧二进制。

- **情况**：验证打包是否成功。
  **要求**：**绝不要**用 `./scripts/build-app.sh | tail` / `| head` 之类管道来跑打包，因为管道的退出码是末段命令的（通常 0），会吞掉脚本失败。直接运行并检查 `echo EXIT=$?`，再用 `ls -la dist/XFinder.app/Contents/MacOS/XFinder` 确认 binary 的 mtime/大小真的变了。
  **原因**：管道吞退出码会导致"以为打包了、其实没打包"，运行的是旧版本，下游所有"验证"全是假的。

- **情况**：`Import Finder Windows` 走 AppleScript 控制 Finder（Apple Events 自动化）。
  **要求**：`build-app.sh` 必须 `codesign --force --deep --sign - "$APP_DIR"` 给 .app 做 ad-hoc 签名（已加）。
  **原因**：**未签名**的 app 无法被授予 Apple Events 自动化权限，macOS 会直接拒绝（或根本不弹授权框），导入静默失败。ad-hoc 签名后才会弹"XFinder 想控制 Finder"，授权后才生效；每次重新打包 cdhash 变，会重新弹一次，属正常。

- **情况**：判断改动是否真的生效。
  **要求**：改完代码 → `swift build` → `swift test` → `./scripts/build-app.sh`（看到 `Built …`）→ `pkill -x XFinder; open -n dist/XFinder.app`。报告时给出 binary mtime 作为证据，而不是"我重启了"。
  **原因**：GUI 在本环境无法自动截图核验，binary 时间戳是唯一能证明"真的重新打包了"的客观证据。

## 测试

- **情况**：本机只有 Command Line Tools，没有完整 Xcode。
  **要求**：测试用 swift-testing（`import Testing` / `@Test` / `#expect`），**不要用 XCTest**（`import XCTest` 会报 `no such module 'XCTest'`）。
  **原因**：XCTest 随完整 Xcode 提供；`Testing.framework` 随 Swift 工具链提供，CLT 环境只有后者。

- **要求**：纯逻辑（日期格式化、布局元数据等）抽成可注入依赖的纯函数并写测试；涉及框架运行时的行为（`WorkspaceStore`、文件操作）写 `@MainActor @Test` 集成测试。

- **情况**：测试 `WorkspaceStore` 时不能污染真实的 Application Support / 用户数据。
  **要求**：用 `WorkspaceStore(supportDirectory: <临时目录>)` 注入持久化路径；文件操作测试在 `FileManager.temporaryDirectory` 下建临时文件夹跑、用完删。
  **原因**：默认 `init()` 会读写真实 `~/Library/Application Support/XFinder`；不注入就会让测试有副作用、不确定。

## 代码风格 / 格式化

- **要求**：改完 Swift 代码跑 `swift format format -i --recursive Sources Tests`；提交前 `swift format lint --strict --recursive Sources Tests` 必须 0 违规。配置在 `.swift-format`（4 空格缩进、行宽 120、import 排序等）。CI 有 lint 门禁，不过就红。
  **原因**：AI 生成的 Swift 风格会漂移；有 formatter + CI 门禁才能让多轮 AI 改动保持一致、diff 干净。

## UI 约定

- **情况**：列表斑马纹曾经钉在视口上，滚动时与行错位。
  **要求**：交替底色必须画在每一行内（随内容滚动），空白区用受视口高度限制的 `ListStripeFiller` 填充；行高/选中块/斑马纹统一读 `FileRowMetrics`，不要写死。
  **原因**：钉视口的背景层不随 `ScrollView` 滚动，必然错位；分散的魔法数字会让几处对不齐。

- **要求**：文件/文件夹图标用 `NSWorkspace.shared.icon(forFile:)`（真实系统图标），不要用 SF Symbol 近似；选中时图标不变色（只有文字和展开箭头变白）。

- **情况**：在 `.onChange(of:)` 闭包里调用方法去读 `self` 的其它属性（如 `self.workspace.directories`）。
  **要求**：`onChange` 闭包里读到的 `self` 是**更新前的旧值**，必须用闭包参数传进来的新值，不能读 `self.xxx`。把需要的新数据作为参数传给被调方法（如 `correctStaleFocus(in: newDirectories)`）。
  **原因**：曾导致"新建面板后焦点被拉回第一个"——onChange 读旧 directories，把刚加的面板误判为已失效而重置焦点。

- **要求**：跨视图共享的状态（如当前聚焦面板 `focusedPaneID`）放在 store 单一数据源里、在 store 方法内同步设置，不要靠"方法返回 id → 视图赋值 @Binding → 传播回各视图"这条链路，时序不可靠。

## 通用

- 只用 SwiftPM 一个包管理器；`.build/`、`dist/`、`release/`、`AI_CONTEXT.md` 保持 gitignore。
- 避免 `NavigationSplitView`（标题栏间距不可控），用自定义 sidebar/content split。
