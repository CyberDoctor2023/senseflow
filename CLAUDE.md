# SenseFlow - Claude 工作指南

**项目**: SenseFlow - macOS 智能剪贴板管理工具
**当前版本**: v0.4 (开发中: v0.5)
**系统要求**: macOS 26.0+

---

## 开始新任务

**必读文件** (按顺序):
1. `docs/SPEC.md` - 唯一真源 spec
2. `docs/TODO.md` - 当前任务清单
3. `docs/DECISIONS.md` - 架构决策记录

---

## 标准开发流程

1. `/openspec:proposal` - 创建变更提案
2. `/openspec:design` - 设计实现方案
3. **Context7 调研** - 查询最新 API 文档（必须！）
   - ❌ **禁止妥协**: 第一次没找到必须换关键词继续查
   - ✅ 至少尝试 3 次不同查询组合
   - ✅ 尝试不同库名和关键词直到找到官方文档
4. **记录引用** - 将调研结果写入 `docs/refs.md`（最多 3 条，每条 ≤ 10 行）
5. `/openspec:apply` - 应用变更到代码
6. **小步提交** - `type(scope): summary` 格式

---

## 项目规则

- ❌ 禁止在聊天中长篇复述 spec/决策
- ✅ 引用文件 + 简短总结（≤ 3 行）
- ✅ Context7 只取 3 条最相关引用
- ✅ 每个提交只做一个主题
- ❌ 禁止硬编码版本号 - 使用 `Bundle.main.infoDictionary["CFBundleShortVersionString"]`
- ❌ **不要主动构建验证** - 先完成改动，只在明确要求时才运行 `/build-check` 或 xcodebuild 验证

---

## 项目工具

- `/build-check` - 快速构建验证
- `/perf-test` - 运行性能测试（CPU/DB/动画/内存）
- `/release-prep` - 发布前检查清单

---

## 项目特定配置

**技术参考**: `.claude/skills/`
- `xcode-project-management.md` - Xcode 项目文件管理
- `database-performance.md` - 数据库架构和性能
- `animation-standards.md` - 动画参数标准

**项目增强**: `.claude/agents/`
- `architect-project.md` - SenseFlow 架构要求
- `reviewer-project.md` - 项目代码审查清单
- `tester-project.md` - 项目测试指标

**质量保障**: `.claude/hooks/` - 自动检查 Xcode 项目更新、动画参数

**自动化**: `.claude/hooks/post-merge-cleanup.sh` - main 分支合并后自动清理
- 自动归档已完成的 openspec 变更
- 自动更新 TODO.md 任务状态
- 自动删除临时文件
- 详见 `docs/GIT_HOOKS_GUIDE.md`

---

**最后更新**: 2026-02-03
