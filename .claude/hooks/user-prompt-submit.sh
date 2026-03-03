#!/bin/bash
# User Prompt Submit Hook - Reminds to use OpenSpec for new features

# Check if user is requesting a new feature
if echo "$USER_MESSAGE" | grep -qiE "(add|implement|create) (feature|功能|新增)"; then
    echo "💡 提醒: 新功能建议使用 OpenSpec 工作流"
    echo "   1. /openspec:proposal - 创建变更提案"
    echo "   2. /openspec:design - 设计实现方案"
    echo "   3. Context7 调研最新 API"
    echo "   4. /openspec:apply - 应用变更"
fi

# Check if user is asking about API/documentation
if echo "$USER_MESSAGE" | grep -qiE "(api|文档|how to|怎么)"; then
    echo "📚 提醒: 可以使用 Context7 查询最新文档"
fi
