#!/bin/bash
# Post Edit Hook - SenseFlow 项目特定检查

FILE_PATH="$1"

# Xcode project management check
if [[ "$FILE_PATH" == *.swift ]]; then
    # Check if this is a new Swift file in SenseFlow directory
    if [[ "$FILE_PATH" == *"/SenseFlow/"* ]] && [[ ! -f "$FILE_PATH.tracked" ]]; then
        echo "⚠️  重要: 新增 Swift 文件需要更新 Xcode 项目文件"
        echo "   需要手动更新: SenseFlow.xcodeproj/project.pbxproj"
        echo "   必需部分: PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase"
        echo "   参考: .claude/skills/xcode-project-management.md"
    fi

    # Check animation parameters against project standards
    if grep -qE "\.snappy\(|\.smooth\(" "$FILE_PATH"; then
        echo "💡 提醒: 检查动画参数是否符合项目标准"
        echo "   参考: .claude/skills/animation-standards.md"
    fi
fi
