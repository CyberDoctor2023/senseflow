# Git Hooks 自动化指南

本项目使用 Git hooks 和 Claude hooks 实现自动化工作流。

---

## 已配置的自动化

### 1. Post-Merge 自动清理（main 分支）

**触发时机**: 当分支合并到 main 后自动执行

**自动化任务**:
1. ✅ 删除临时 TODO 文件（如 `KEYCHAIN_BATCH_READ_TODO.md`）
2. ✅ 归档已完成的 openspec 变更到 `openspec/changes/archive/`
3. ✅ 更新 `docs/TODO.md` 中的任务状态（标记为已完成）
4. ✅ 自动提交清理改动

**实现文件**:
- `.claude/hooks/post-merge-cleanup.sh` - Claude hook 脚本
- `.git/hooks/post-merge` - Git hook（调用 Claude hook）

**工作流程**:
```bash
# 1. 合并分支到 main
git checkout main
git merge fix/some-feature

# 2. Git 自动触发 post-merge hook
# 3. 检测到 merge commit，执行清理脚本
# 4. 自动归档 openspec、更新 TODO、提交改动
```

**示例输出**:
```
🔄 [Post-Merge] 检测到 main 分支合并，开始自动清理...
📦 被合并的分支: fix/keychain-permissions
📁 归档 openspec 变更: batch-keychain-reads-on-settings-load
✅ 标记任务完成: CITRO-432
💾 提交自动清理的改动...
✅ [Post-Merge] 自动清理完成
```

---

## 安装指南

### 首次设置（已完成）

Git hooks 已安装在 `.git/hooks/post-merge`，无需手动操作。

### 验证安装

检查 hook 是否正确安装：

```bash
# 检查 hook 文件存在且可执行
ls -la .git/hooks/post-merge

# 检查 Claude hook 存在且可执行
ls -la .claude/hooks/post-merge-cleanup.sh
```

---

## 手动触发清理

如果需要手动运行清理脚本：

```bash
cd /Users/jack/Documents/AI_clipboard
./.claude/hooks/post-merge-cleanup.sh
```

---

## 自定义配置

### 跳过自动清理

如果某次合并不想触发自动清理，可以临时禁用 hook：

```bash
# 方法 1: 使用 --no-verify 跳过 hooks
git merge --no-verify fix/some-feature

# 方法 2: 临时重命名 hook
mv .git/hooks/post-merge .git/hooks/post-merge.disabled
git merge fix/some-feature
mv .git/hooks/post-merge.disabled .git/hooks/post-merge
```

### 修改清理规则

编辑 `.claude/hooks/post-merge-cleanup.sh` 自定义清理逻辑：

```bash
# 示例：添加新的清理规则
if [ -f "some-temp-file.txt" ]; then
    echo "🗑️  删除临时文件..."
    git rm -f some-temp-file.txt
    HAS_CHANGES=true
fi
```

---

## 故障排查

### Hook 没有执行

1. 检查 hook 是否可执行：
   ```bash
   ls -la .git/hooks/post-merge
   # 应该显示 -rwxr-xr-x（有 x 权限）
   ```

2. 检查 Claude hook 是否可执行：
   ```bash
   ls -la .claude/hooks/post-merge-cleanup.sh
   ```

3. 手动运行测试：
   ```bash
   ./.claude/hooks/post-merge-cleanup.sh
   ```

### Hook 执行失败

查看错误信息：
```bash
# 在 merge 时会显示错误输出
git merge fix/some-feature
```

调试模式运行：
```bash
bash -x ./.claude/hooks/post-merge-cleanup.sh
```

---

## 其他 Claude Hooks

项目中还有其他 hooks：

- `pre-tool-use.sh` - 工具使用前检查
- `post-edit.sh` - 文件编辑后检查
- `user-prompt-submit.sh` - 用户提交前检查

详见各 hook 文件的注释说明。

---

**最后更新**: 2026-01-29
