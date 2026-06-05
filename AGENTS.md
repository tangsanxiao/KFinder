# AGENTS.md — KFinder 项目协作规则

> 给所有在本仓库工作的 AI/人。每条都是踩过的坑的根因（情况 → 要求 → 原因）。

## 构建与打包

- **情况**：`scripts/build-app.sh` 用 `set -euo pipefail`，里面的 `git describe --tags --exact-match` 在 HEAD 没有精确 tag 时返回 128。
  **要求**：脚本里每个可能失败的 `git` 调用都要以 `|| true` 收尾（即使有 `2>/dev/null`）。
  **原因**：`2>/dev/null` 只藏住报错信息，`set -e`/`pipefail` 仍会让整个脚本在算版本号那步中止，`swift build` 根本不执行，dist 静默保留旧二进制。

- **情况**：验证打包是否成功。
  **要求**：**绝不要**用 `./scripts/build-app.sh | tail` / `| head` 之类管道来跑打包，因为管道的退出码是末段命令的（通常 0），会吞掉脚本失败。直接运行并检查 `echo EXIT=$?`，再用 `ls -la dist/KFinder.app/Contents/MacOS/KFinder` 确认 binary 的 mtime/大小真的变了。
  **原因**：管道吞退出码会导致"以为打包了、其实没打包"，运行的是旧版本，下游所有"验证"全是假的。

- **情况**：`Import Finder Windows` 走 AppleScript 控制 Finder（Apple Events 自动化）。
  **要求**：`build-app.sh` 必须 `codesign --force --deep --sign - "$APP_DIR"` 给 .app 做 ad-hoc 签名（已加）。
  **原因**：**未签名**的 app 无法被授予 Apple Events 自动化权限，macOS 会直接拒绝（或根本不弹授权框），导入静默失败。ad-hoc 签名后才会弹"KFinder 想控制 Finder"，授权后才生效；每次重新打包 cdhash 变，会重新弹一次，属正常。

- **情况**：判断改动是否真的生效。
  **要求**：改完代码 → `swift build` → `swift test` → `./scripts/build-app.sh`（看到 `Built …`）→ `pkill -x KFinder; open -n dist/KFinder.app`。报告时给出 binary mtime 作为证据，而不是"我重启了"。
  **原因**：GUI 在本环境无法自动截图核验，binary 时间戳是唯一能证明"真的重新打包了"的客观证据。

## 测试

- **情况**：本机只有 Command Line Tools，没有完整 Xcode。
  **要求**：测试用 swift-testing（`import Testing` / `@Test` / `#expect`），**不要用 XCTest**（`import XCTest` 会报 `no such module 'XCTest'`）。
  **原因**：XCTest 随完整 Xcode 提供；`Testing.framework` 随 Swift 工具链提供，CLT 环境只有后者。

- **要求**：纯逻辑（日期格式化、布局补齐面板数等）抽成可注入依赖的纯函数/可独立调用的方法并写测试；涉及框架运行时的行为（如 `WorkspaceStore.applyLayout`）写 `@MainActor @Test` 集成测试。

## UI 约定

- **情况**：列表斑马纹曾经钉在视口上，滚动时与行错位。
  **要求**：交替底色必须画在每一行内（随内容滚动），空白区用受视口高度限制的 `ListStripeFiller` 填充；行高/选中块/斑马纹统一读 `FileRowMetrics`，不要写死。
  **原因**：钉视口的背景层不随 `ScrollView` 滚动，必然错位；分散的魔法数字会让几处对不齐。

- **要求**：文件/文件夹图标用 `NSWorkspace.shared.icon(forFile:)`（真实系统图标），不要用 SF Symbol 近似；选中时图标不变色（只有文字和展开箭头变白）。

## 通用

- 只用 SwiftPM 一个包管理器；`.build/`、`dist/`、`release/`、`AI_CONTEXT.md` 保持 gitignore。
- 避免 `NavigationSplitView`（标题栏间距不可控），用自定义 sidebar/content split。
