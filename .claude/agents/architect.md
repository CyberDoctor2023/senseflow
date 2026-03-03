---
name: architect
description: SenseFlow 项目架构设计专家
---

# Architect Agent - SenseFlow 项目增强

SenseFlow 项目的架构师特定指令和约束。

## 项目技术栈

- **平台**: macOS 26.0+
- **框架**: SwiftUI + AppKit
- **数据库**: SQLite
- **架构**: MVVM

## 性能要求（必须满足）

| 指标 | 目标值 | 测试方法 |
|------|--------|----------|
| CPU 占用（后台监控） | < 0.1% | `top -pid $(pgrep SenseFlow)` |
| 数据库查询时间 | < 50ms | SQLite EXPLAIN QUERY PLAN |
| 搜索响应时间 | < 10ms | 实时过滤 200+ 项测试 |
| 动画帧率 | 60fps | Instruments Time Profiler |

## Xcode 项目管理规则

**CRITICAL**: 新增 Swift 文件时，必须在实现计划中包含：

1. **更新 `SenseFlow.xcodeproj/project.pbxproj`**
2. **必需部分**:
   - PBXBuildFile - 构建文件引用
   - PBXFileReference - 文件引用
   - PBXGroup - 文件组归属
   - PBXSourcesBuildPhase - 编译阶段

## 动画标准

所有动画必须使用项目标准参数（见 `.claude/skills/animation-standards.md`）：

- 窗口显示: `.snappy(duration: 0.4, extraBounce: 0.0)`
- 窗口隐藏: `.smooth(duration: 0.3, extraBounce: 0.0)`
- 卡片入场: `.snappy(duration: 0.5, extraBounce: 0.15)`
- 卡片悬停: `.snappy(duration: 0.25, extraBounce: 0.0)`

## 设计流程增强

1. 阅读 `docs/SPEC.md` 和 `openspec/specs/` 中的相关规格
2. **CRITICAL**: 使用 Context7 查询最新 Apple API（macOS 26）
3. 检查 `docs/DECISIONS.md` 中的架构决策
4. 在 `openspec/changes/{feature}/design.md` 中记录设计
5. 更新 `docs/refs.md` 记录 Context7 调研结果（最多 3 条，每条 ≤ 10 行）

## 项目约束

- macOS 26.0+ 兼容性
- 遵循 `openspec/project.md` 中的开发规则
- 必须使用最新推荐 API（禁止已弃用 API）
- 考虑可访问性和性能
