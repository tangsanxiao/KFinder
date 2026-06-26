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

- **情况**：视图代码（`@MainActor`）里直接同步调用 `FileBrowserService.contents` / `FileManager` 读目录。
  **要求**：视图里的目录读取一律走 `FileBrowserService.contents` 的 **async 重载**（内部 `Task.detached` 下沉到后台线程）；并发 reload 用 generation 计数丢弃过期结果，防止慢目录覆盖新结果。
  **原因**：同步 IO 跑在主线程，遇到大目录（node_modules、大 Downloads）整个 UI 卡死，与"高性能"目标直接冲突。

- **情况**：`onDrop` 收到多个文件（每个文件一个 `NSItemProvider`）。
  **要求**：处理拖放必须遍历**所有** provider，不能 `providers.first(where:)` 只取第一个。
  **原因**：曾导致多选拖放只移动了一个文件，其余静默丢弃，用户以为全移了。

- **情况**：SwiftUI `.onDrag` 每个视图只能返回**一个** `NSItemProvider`，无法表达多选拖拽。
  **要求**：应用内多文件拖拽走 store 的 `dragPayload`（onDrag 时记录整组选中 URL，onDrop 时优先消费它，外部 Finder 拖入才回退到 providers）；放置时跳过"已在目标目录"的文件（同目录拖放应是 no-op，不能复制）；文件夹行要自己加 `.onDrop` 才能作为放置目标。
  **原因**：曾导致①同文件夹拖放复制一份 ②无法拖进面板内子文件夹 ③多选拖到另一面板只移动一个。

- **情况**：layout 和 directories（面板列表）是两份独立状态，曾经只在关面板时对齐。
  **要求**：任何**新增面板**的代码路径（`openInNewPane`、`addDirectories`、未来的导入等）都必须经过 `fitLayoutAfterAddingPanes`：面板数超过 `layout.preferredPaneCount` 时自动升档，但不降档（保留用户选的大布局和占位符）。
  **原因**：曾导致 Single 布局下加第二个面板时被静默挤成上下两行，顶部 Layout 图标却没变——面板与布局状态对不齐。

- **情况**：工具栏按钮的即时 tooltip 曾经是"共享状态 + 锚定在工具栏右上角"的单一气泡。
  **要求**：tooltip 气泡必须由按钮自己渲染（`PaneToolbarActionButton` 内置，或对 Menu 等用 `.toolbarTip(_:isPresented:)`），且气泡会伸出工具栏下沿——工具栏容器必须比下方内容 `zIndex` 更高。
  **原因**：锚定角落的气泡不跟随鼠标（左侧按钮的提示出现在最右边）；z 序不够会被下方文件面板盖住。

- **情况**：键盘快捷键经由每个面板安装的 `NSEvent.addLocalMonitorForEvents` 处理（见 `BrowserPaneView.handleKeyDown`）。
  **要求**：handler 必须先做三重放行检查（非聚焦面板 / 正在重命名 / `firstResponder is NSTextView`）再消费事件；新增快捷键加进 `handleKeyDown` 的 switch，不要再装新的 monitor。
  **原因**：local monitor 是 app 级的，每个面板都会收到所有按键；不检查焦点会让多个面板同时响应，不检查文本输入会吞掉用户在 TextField 里的打字。

- **情况**：`.onAppear` 安装的长生命周期闭包（NSEvent monitor、Task 循环等）捕获的是**安装时刻的视图结构体副本**。
  **要求**：这类闭包里**绝不能读视图的 `let` 属性**（如 `isFocused`、`viewMode`）做判断——它们被永久冻结在安装时的值。必须改读 live 来源：store 的 `@Published`（引用类型，永远最新，如 `store.focusedPaneID == root.id`）或 `@State`（存储盒跨渲染共享；let 需要时用 @State 镜像 + `onChange` 同步）。
  **原因**：曾导致"点了右面板、方向键却操作左面板"——monitor 闭包里冻结的 `isFocused` 让安装时聚焦的面板永远认为自己有焦点。SwiftUI 每次渲染都重建结构体，但旧闭包持有旧副本。

- **情况**：列表斑马纹曾经钉在视口上，滚动时与行错位。
  **要求**：交替底色必须画在每一行内（随内容滚动），空白区用受视口高度限制的 `ListStripeFiller` 填充；行高/选中块/斑马纹统一读 `FileRowMetrics`，不要写死。
  **原因**：钉视口的背景层不随 `ScrollView` 滚动，必然错位；分散的魔法数字会让几处对不齐。

- **要求**：文件/文件夹图标用 `NSWorkspace.shared.icon(forFile:)`（真实系统图标），不要用 SF Symbol 近似；选中时图标不变色（只有文字和展开箭头变白）。

- **情况**：需要在某个区域改变鼠标光标（列分隔线的 resize 等）。
  **要求**：用 SwiftUI 原生 `pointerStyle`（macOS 15+，见 `columnResizeCursor()`），不要在 SwiftUI 覆盖层里塞 AppKit 子视图去改光标（cursor-rect / tracking area / cursorUpdate 都试过）。
  **原因**：`NSHostingView` 接管了整个 SwiftUI 子树的光标管理，覆盖层里的 AppKit 子视图无论用哪种机制都赢不过它——要么光标根本不显示，要么和宿主来回抢导致闪动。只有用 SwiftUI 自己的光标 API 才不冲突。

- **情况**：拖拽一个"会随被拖动对象移动而移动"的手柄（列分隔线、Main+Stack 分隔条）。
  **要求**：`DragGesture` 必须指定 `coordinateSpace: .global`，不要用默认的视图本地坐标系。
  **原因**：手柄随列宽/面板宽变化而移动时，视图本地的 `translation` 参照系也跟着动，形成正反馈，后面那列会抖动。global 坐标系只跟鼠标绝对移动有关，断开反馈环。

- **情况**：在 `.onChange(of:)` 闭包里调用方法去读 `self` 的其它属性（如 `self.workspace.directories`）。
  **要求**：`onChange` 闭包里读到的 `self` 是**更新前的旧值**，必须用闭包参数传进来的新值，不能读 `self.xxx`。把需要的新数据作为参数传给被调方法（如 `correctStaleFocus(in: newDirectories)`）。
  **原因**：曾导致"新建面板后焦点被拉回第一个"——onChange 读旧 directories，把刚加的面板误判为已失效而重置焦点。

- **要求**：跨视图共享的状态（如当前聚焦面板 `focusedPaneID`）放在 store 单一数据源里、在 store 方法内同步设置，不要靠"方法返回 id → 视图赋值 @Binding → 传播回各视图"这条链路，时序不可靠。

- **情况**：切换 workspace 会销毁并重建所有 `BrowserPane`，其 `@State` 全部重置。
  **要求**：任何"用户为某个面板设置、且期望切回来还在"的状态（排序、视图模式、导航位置等）**不能只存 `@State`**，必须按 pane id 存进 store 并持久化（参考 `paneSortOrder`/`paneLocations` 的 load/save/prune 三件套，删面板时一并清理）。
  **原因**：曾导致切走再切回后按修改时间排序丢失、退回默认。`@State` 只活在视图实例的生命周期内。

- **情况**：行右键菜单作用于多选（Trash / Copy To / Move To / Compress / Ask Claude）。
  **要求**：这类操作必须遍历 `actionTargets(for:)` 返回的全部目标，不能只对被右键的那一行 `row.file` 生效。新增的行级批量操作走 `trashTargets`/`copyTargets`/`moveTargets` 这类统一入口。
  **原因**：曾导致选中多个文件却只删/只移了一个，其余静默不动。

## 跨 agent 中心(Skill / Session)

- **要求**:扫描各 agent 目录的能力(Skill Center、Session Center)默认**只读**;解析按 agent 写独立适配器,且解析逻辑(frontmatter / JSONL 行 → 消息、token 估算)抽成纯函数放 `*Models`/`*Parsing` 并配单测,文件 IO 放 `*Scanner`。
- **要求**:列表扫描必须**廉价**——会话文件可能很大(单机 ~400MB),列表只 stat + 头部读(`FileHandle.read(upToCount:)`),完整解析(transcript)在选中时惰性做;token 是估算(≈,字符/4 或字节/4),UI 要标注"≈"。
- **情况**:Agent Inbox 聚合项目列表时同时扫 git 与 session。
  **要求**:Inbox 入口必须复用 `WorkspaceStore` 缓存;列表扫描只做 session summary/git status/轻量风险规则,完整 transcript 抽取只能在选中项目后懒加载;隐藏/置顶这类用户治理状态要持久化并配纯逻辑测试。
  **原因**:曾经每次进入 Inbox 都全量扫描并解析多个完整 transcript,切换入口也会变慢;项目噪音无法治理会让主入口失去审查价值。
- **要求**:`FileManager.DirectoryEnumerator` 的迭代在 async 上下文不可用,递归收集文件要放在**同步**辅助函数里再被 async 调用。
- **情况**:第三方 LLM(会话总结)需要用户自填 API key。
  **要求**:默认关闭;key 存本机设置、只发往用户配置的 endpoint;请求构造(`makeRequest`)和响应解析(`parseContent`)写成纯函数配单测,网络调用单独一层。**绝不**把 key 发往其它地方或记日志。

## 通用

- **要求**：用户可感知的操作结果一律走 `store.statusMessage` / `store.lastError`，不要 print 或静默吞掉。这两个属性的 didSet 会自动进入 app 内的 Activity & Errors 面板，是排错的唯一线索来源。
- **要求**：`build-app.sh` 会把 `CHANGELOG.md` 拷进 app bundle 供"What's New"面板展示——改 CHANGELOG 后要重新打包才能在 app 内看到。

- 只用 SwiftPM 一个包管理器；`.build/`、`dist/`、`release/`、`AI_CONTEXT.md` 保持 gitignore。
- 避免 `NavigationSplitView`（标题栏间距不可控），用自定义 sidebar/content split。
