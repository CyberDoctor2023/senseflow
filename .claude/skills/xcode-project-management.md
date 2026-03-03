# Xcode Project Management

管理 Xcode 项目文件和构建配置的最佳实践。

## 添加新文件到 Xcode 项目

### ⚠️ 重要规则

**新增 Swift 文件时，必须手动更新 `SenseFlow.xcodeproj/project.pbxproj`**

### 必需部分

1. **PBXBuildFile** - 构建文件引用
2. **PBXFileReference** - 文件引用
3. **PBXGroup** - 文件组归属
4. **PBXSourcesBuildPhase** - 编译阶段

### ID 命名规范

- 使用唯一 ID 前缀：
  - `B` + 数字 → PBXBuildFile
  - `F` + 数字 → PBXFileReference
  - `G` + 数字 → PBXGroup

### 示例：添加 AccessibilityManager.swift

```ruby
# 使用 Ruby 脚本自动添加文件
ruby -e "
require 'xcodeproj'
project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 获取 Managers 组
managers_group = project.main_group['SenseFlow']['Managers']

# 获取 target
target = project.targets.first

# 添加文件
file = managers_group.new_file('SenseFlow/Managers/AccessibilityManager.swift')
target.add_file_references([file])

project.save
puts '✅ 文件已添加到 Xcode 项目'
"
```

## 构建配置

### 编译命令

```bash
# Debug 模式
xcodebuild -scheme SenseFlow -configuration Debug

# Release 模式
xcodebuild -scheme SenseFlow -configuration Release

# 清理构建
xcodebuild clean -scheme SenseFlow
```

### 性能检查

```bash
# 监控 CPU 占用
top -pid $(pgrep SenseFlow) -stats cpu,mem

# 检查数据库性能
time sqlite3 ~/Library/Application\ Support/SenseFlow/clipboard.sqlite "SELECT COUNT(*) FROM clipboard_history;"
```

## 项目结构规范

```
SenseFlow/
├── Models/          # 数据模型
├── Views/           # SwiftUI 视图
├── Managers/        # 业务逻辑（窗口、剪贴板、快捷键）
└── Services/        # 底层服务（数据库、OCR）
```

## 权限配置

### Info.plist 必需项

- `NSAppleEventsUsageDescription` - 自动粘贴权限说明
- `NSAccessibilityUsageDescription` - Accessibility 权限说明

### Entitlements

- `com.apple.security.automation.apple-events` - 允许自动化

## 常见问题

### Debug 模式每次需要重新授权 Accessibility

**原因**: Debug 模式每次编译签名变化
**解决**: Release 版本只需授权一次
