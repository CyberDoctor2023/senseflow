# Git Worktrees 管理

**创建日期**: 2026-01-28
**项目版本**: v0.4 → v0.5

---

## 当前活跃的 Worktrees

### 1. CITRO-430: 设置面板 UI 错位
```bash
cd ../AI_clipboard-settings-ui
```
- **分支**: `fix/settings-ui-layout`
- **问题**: NavigationSplitView columnWidth workaround
- **优先级**: P1
- **状态**: 🔴 未开始

### 2. CITRO-432: 钥匙串权限弹窗烦人
```bash
cd ../AI_clipboard-keychain
```
- **分支**: `fix/keychain-permissions`
- **问题**: 频繁弹出钥匙串授权请求
- **优先级**: P1
- **状态**: 🔴 未开始

### 3. CITRO-434: 历史剪切板动画效果卡顿
```bash
cd ../AI_clipboard-animation
```
- **分支**: `fix/animation-performance`
- **问题**: 卡片切换动画性能问题
- **优先级**: P1
- **状态**: 🔴 未开始

### 4. CITRO-435: 不兼容早期 Mac 版本
```bash
cd ../AI_clipboard-compatibility
```
- **分支**: `fix/mac-compatibility`
- **问题**: macOS 26.0+ 限制过高
- **优先级**: P2
- **状态**: 🔴 未开始

---

## 工作流程

### 开始任务
```bash
cd ../AI_clipboard-<name>
claude
> /rename <issue-id>
> /openspec:proposal
> /openspec:apply
```

### 完成任务
```bash
# 1. 提交代码
git add .
git commit -m "fix: <description>"

# 2. 推送到远程
git push -u origin <branch-name>

# 3. 合并到主分支
cd ~/Documents/AI_clipboard
git merge <branch-name>

# 4. 删除 worktree
git worktree remove ../AI_clipboard-<name>
```

### 查看所有 worktrees
```bash
git worktree list
```

---

## OpenSpec + Worktrees 协调

### 方案：独立提案 + 分支合并（推荐）

每个 worktree 独立创建 OpenSpec 提案：
- 提案路径: `openspec/changes/<issue-id>/`
- 提案和代码在同一分支
- 合并时提案一起进入主分支

**优势**:
- ✅ 提案和实现原子性强
- ✅ 适合独立功能开发
- ✅ 分支历史清晰

---

## 注意事项

1. **环境初始化**: 每个 worktree 已自动同步代码，无需额外配置
2. **分支隔离**: 各 worktree 文件状态完全独立
3. **定期清理**: 完成任务后立即删除 worktree
4. **会话命名**: 在每个 worktree 中用 `/rename` 命名 Claude 会话

---

**维护**: 完成任务后更新状态，删除对应 worktree
