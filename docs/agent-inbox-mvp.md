# Agent Inbox / Review Workbench MVP

## 目标

把 XFinder 的 AI 能力从分散入口收敛成一个本地开发者可用的 Agent Inbox：

- 聚合本机 Claude / Codex 会话和当前项目 git 变更。
- 按项目、时间和 agent 展示最近活动。
- 帮用户快速 review agent 改动：看 diff、识别风险、查看测试状态、生成 commit message。
- 保持本地优先、显式授权，不做团队版和云端索引。

## 本轮范围

### 做

- 新增侧边栏入口 `Agent Inbox`。
- 本地扫描 Claude / Codex 会话摘要，按项目聚合。
- 读取每个项目的 git 状态、最近提交、最近变更。
- 为每个项目生成 Review Summary：
  - agent 活动数量与最近时间。
  - git 变更数量与风险等级。
  - secret / 敏感路径提示。
  - 选中项目后懒加载的决策 / 待办。
  - 本地规则版 commit message 草稿。
- 支持从 inbox 打开项目到文件面板、打开 Terminal、打开 Claude Code、查看变更 diff。
- 支持本机置顶项目,并可多选批量隐藏项目,降低低价值项目噪音。
- Session Center 增强为基础全文搜索能力。
- 补测试覆盖纯解析、聚合、风险扫描、commit message 草稿。

### 不做

- 团队版。
- Cursor / Windsurf / GitHub Copilot 连接器。
- 完整官网。
- Developer ID / notarization / auto update 实现。
- OS 级全量记忆。
- 重型 IDE 编辑、调试、测试执行器。

## 验收标准

- 用户能在侧边栏进入 Agent Inbox。
- 至少能看到 Claude / Codex 会话所在项目列表。
- 重复进入 Agent Inbox 复用缓存,手动刷新才全量重扫;完整 transcript 只在选中项目后读取。
- 对 git repo 项目能看到未提交变更、最近变更和最近 commits。
- 变更项能打开 diff，能跳转到文件面板。
- 相关会话能跳转到完整会话视图。
- 不重要项目能多选批量隐藏,重要项目能置顶,偏好保存在本机。
- 有本地规则版风险提示和 commit message 草稿。
- Secret / 敏感路径命中会显著提示。
- `swift format lint --strict --recursive Sources Tests`、`swift build`、`swift test`、`./scripts/build-app.sh` 通过。
