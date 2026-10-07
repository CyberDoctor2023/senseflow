#!/bin/bash
# Post-merge cleanup hook for main branch
# 自动更新 TODO、归档 openspec、清理临时文件

set -e

# 获取当前分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 只在 main 分支执行
if [ "$CURRENT_BRANCH" != "main" ]; then
    exit 0
fi

echo "🔄 [Post-Merge] 检测到 main 分支合并，开始自动清理..."

# 获取被合并的分支名
# 尝试从 merge commit 获取
MERGED_BRANCH=$(git log -1 --merges --format=%s | sed -n "s/^Merge branch '\([^']*\)'.*/\1/p")

# 如果不是 merge commit（快进合并），从 ORIG_HEAD 获取
if [ -z "$MERGED_BRANCH" ] && [ -f ".git/ORIG_HEAD" ]; then
    # 获取合并前的分支名（从 reflog）
    MERGED_BRANCH=$(git reflog -1 | sed -n "s/.*checkout: moving from .* to \(.*\)/\1/p")

    # 如果还是获取不到，尝试从最近的提交信息中提取
    if [ -z "$MERGED_BRANCH" ]; then
        MERGED_BRANCH=$(git log -1 --format=%s | grep -oE '(fix|feat|test)/[a-z0-9-]+' | head -1)
    fi
fi

if [ -z "$MERGED_BRANCH" ]; then
    echo "⚠️  无法检测被合并的分支名，跳过自动清理"
    exit 0
fi

echo "📦 被合并的分支: $MERGED_BRANCH"

# 标记是否有改动
HAS_CHANGES=false

# 1. 清理临时 TODO 文件（匹配 *_TODO.md 或 *TODO.md 模式）
for todo_file in *TODO.md *_TODO.md; do
    if [ -f "$todo_file" ]; then
        echo "🗑️  删除临时 TODO 文件: $todo_file"
        git rm -f "$todo_file" 2>/dev/null || rm -f "$todo_file"
        HAS_CHANGES=true
    fi
done

# 2. 归档已完成的 openspec 变更
# 从分支名提取 openspec 变更名（如 fix/keychain-permissions -> batch-keychain-reads-on-settings-load）
OPENSPEC_PATTERN=$(echo "$MERGED_BRANCH" | sed 's|^[^/]*/||' | sed 's|-|.*|g')

if [ -d "openspec/changes" ]; then
    for dir in openspec/changes/*/; do
        dirname=$(basename "$dir")
        # 跳过 archive 目录
        if [ "$dirname" = "archive" ]; then
            continue
        fi

        # 检查目录名是否匹配分支名模式
        if echo "$dirname" | grep -qi "$OPENSPEC_PATTERN"; then
            echo "📁 归档 openspec 变更: $dirname"
            mkdir -p openspec/changes/archive
            git mv "openspec/changes/$dirname" "openspec/changes/archive/" 2>/dev/null || true
            HAS_CHANGES=true
        fi
    done
fi

# 3. 更新 TODO.md 状态
# 从 commit message 中提取任务 ID（如 CITRO-432）
TASK_IDS=$(git log -1 --format=%B | grep -oE 'CITRO-[0-9]+' | sort -u)

if [ -n "$TASK_IDS" ] && [ -f "docs/TODO.md" ]; then
    for TASK_ID in $TASK_IDS; do
        # 检查任务是否存在且未完成
        if grep -q "### $TASK_ID:" docs/TODO.md && ! grep -A 5 "### $TASK_ID:" docs/TODO.md | grep -q "✅ 已完成"; then
            echo "✅ 标记任务完成: $TASK_ID"

            # 获取当前日期
            CURRENT_DATE=$(date +%Y-%m-%d)

            # 更新任务状态（在状态行后添加完成标记）
            sed -i '' "/### $TASK_ID:/,/^###/ {
                s/- \*\*状态\*\*: 🔴 未开始/- **状态**: ✅ 已完成 ($CURRENT_DATE)/
                s/- \*\*状态\*\*: 🟡 进行中/- **状态**: ✅ 已完成 ($CURRENT_DATE)/
            }" docs/TODO.md

            HAS_CHANGES=true
        fi
    done
fi

# 4. 如果有改动，自动提交
if [ "$HAS_CHANGES" = true ]; then
    echo "💾 提交自动清理的改动..."

    git add -A
    git commit -m "chore: auto cleanup after merging $MERGED_BRANCH

自动清理任务：
- 归档已完成的 openspec 变更
- 删除临时 TODO 文件
- 更新任务状态

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || true

    echo "✅ [Post-Merge] 自动清理完成"
else
    echo "ℹ️  [Post-Merge] 无需清理"
fi
