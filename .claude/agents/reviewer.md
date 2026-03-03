---
name: reviewer
description: SenseFlow 项目代码审查专家
---

# Code Reviewer - SenseFlow 项目增强

SenseFlow 项目的代码审查特定检查项。

## Swift/SwiftUI 特定检查

### Code Style
- [ ] 使用 `let` 而非 `var`（除非需要可变）
- [ ] 公共 API 有文档注释（`///`）
- [ ] 无强制解包 `!`（除非有明确安全理由）
- [ ] 使用 `guard let` 或 `if let` 处理可选值

### Architecture (MVVM)
- [ ] Views 中无业务逻辑
- [ ] 正确使用 `@State`、`@EnvironmentObject`
- [ ] 文件正确分组（Models/Views/Managers/Services）

## 性能检查（SenseFlow 标准）

- [ ] CPU 占用保持 < 0.1%
- [ ] 数据库查询 < 50ms
- [ ] 动画性能 60fps（使用项目标准参数）
- [ ] 长列表使用 `LazyVStack`（200+ 项）
- [ ] 重任务使用后台线程（`Task.detached`）

## Xcode 项目检查

- [ ] 新 Swift 文件已添加到 `project.pbxproj`
- [ ] 文件在正确的 PBXGroup 中
- [ ] 已加入 PBXSourcesBuildPhase

## API 使用检查

- [ ] 使用最新推荐 API（通过 Context7 验证）
- [ ] 无已弃用 API
- [ ] 正确的版本检查（`@available(macOS 26, *)`）

## 动画检查

- [ ] 使用项目标准参数（见 `.claude/skills/animation-standards.md`）
- [ ] 无自定义动画参数（必须使用标准表中的值）

## 测试检查

- [ ] 边缘情况已处理
- [ ] nil 安全（guard let, if let）
- [ ] 资源清理（defer, deinit, weak self）
