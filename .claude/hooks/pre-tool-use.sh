#!/bin/bash
# Pre Tool Use Hook - SenseFlow 项目特定检查

TOOL_NAME="$1"

# SenseFlow specific file protection
if [[ "$TOOL_NAME" == "Bash" ]]; then
    # Protect SenseFlow specific files
    if echo "$TOOL_ARGS" | grep -qE "rm.*project\.md|rm.*refs\.md"; then
        echo "🚫 阻止删除 SenseFlow 关键文件"
        exit 1
    fi
fi

# Swift/macOS API usage reminder
if [[ "$TOOL_NAME" == "Write" ]] || [[ "$TOOL_NAME" == "Edit" ]]; then
    if echo "$TOOL_ARGS" | grep -qE "\.swift$"; then
        # Check for macOS/SwiftUI API usage
        if echo "$TOOL_ARGS" | grep -qE "import.*Vision|import.*ServiceManagement|NSGlassEffectView|VNRecognize"; then
            echo "💡 提醒: Swift/macOS API 使用前，请通过 Context7 查询 macOS 26 最新文档"
            echo "   SenseFlow 规则: 必须使用 macOS 26+ 推荐 API"
        fi
    fi
fi
