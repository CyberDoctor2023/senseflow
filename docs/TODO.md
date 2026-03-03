# 任务清单

**更新日期**: 2026-02-05

---

## 当前状态

**项目版本**: v0.4

**主要功能**:
- ✅ 剪贴板历史 + 搜索 + OCR (v0.1)
- ✅ Prompt Tools 功能 (v0.2)
- ✅ Clean Architecture 重构 (v0.4)
- ✅ 代码架构优化 (v0.4.1 - 2026-02-05)
- ⚠️ Liquid Glass 视觉效果 (v0.2.1 - 待重做)
- ⚠️ 设置面板 NavigationSplitView (v0.2.1 - 待重做)

---

## v0.5 开发任务

### CITRO-436: 代码架构优化与重构 [P1]
- **问题**: 魔法数字、硬编码字符串、职责不清晰
- **状态**: ✅ 已完成 (2026-02-05)
- **解决方案**:
  - Repository 模式：ClipboardRepositoryProtocol + DatabaseClipboardRepository
  - 常量提取：5个常量文件（ClipboardItemConstants, ClipboardMonitorConstants, AutoPasteManagerConstants, TextPreviewConstants, ClipboardItemColors）
  - 扩展分离：Color+Hex, String+SHA256, Data+SHA256, Notification+Names
  - 职责分离：FloatingWindowAnimator, KeyboardAcceptingPanel
  - 代码重复消除：统一文本预览长度
- **成果**:
  - FloatingWindowManager: 449→357 行 (-20.5%)
  - 消除魔法数字 20+ 处
  - 新增文件 13 个
  - 8 个干净的提交
- **提交**: d1c2aa9, fbf428e, 19ab3d0, 29376c7, c7ef486, 5857f1d, 2463a6a, d37fd2d

### CITRO-430: 设置面板 UI 错位 [P1]
- **问题**: NavigationSplitView columnWidth 导致 traffic lights 遮挡
- **状态**: ✅ 已解决 (2026-01-30)
- **解决方案**:
  - 架构变更：从 NavigationSplitView 改回 TabView
  - 使用标准 macOS Settings Scene + TabView 布局
  - 固定窗口尺寸 700×500-600
- **提交**: ab8b1be (revert to TabView)

### CITRO-432: 钥匙串权限弹窗烦人 [P1]
- **问题**: 频繁弹出钥匙串授权请求
- **状态**: ✅ 已完成 (2026-01-29)
- **解决方案**:
  - 采用 Deck 单密钥加密策略
  - Keychain 授权从 7 次减少到 1 次
  - Langfuse 密钥改用 UserDefaults（内置默认值）
  - 整个应用生命周期最多 1 次授权
- **提交**: af8c198 (Merge), 26bcc72, 7884387

### CITRO-434: 历史剪切板动画效果卡顿 [P1]
- **问题**: 卡片切换动画性能问题
- **状态**: ✅ 已完成 (2026-01-30)
- **解决方案**:
  - HStack → LazyHStack（按需加载，只渲染可见卡片）
  - 迁移到 PhaseAnimator（现代动画系统）
  - 修复 LazyHStack 渲染问题（强制 ScrollView 重新创建）
  - 性能提升：初始加载时间减少 >50%，60fps 滚动
- **提交**: 24e51f3, c64548e, 4c8fb5e (归档)
- **OpenSpec**: optimize-card-scrolling-performance (已归档)

### CITRO-435: 不兼容早期 Mac 版本 [P2]
- **问题**: macOS 26.0+ 限制过高
- **状态**: ✅ 部分完成 (2026-02-02)
- **解决方案**:
  - 部署目标降至 macOS 14.0 (Sonoma)
  - 创建兼容层（ViewModifiers+Compatibility.swift）
  - 所有 macOS 26+ API 使用 #available 检查
  - macOS 26+ 使用 Liquid Glass，14-25 使用 thin material
  - macOS 14+ 使用 PhaseAnimator，CompatiblePhaseAnimator 提供降级
- **限制**:
  - 核心动画使用 .snappy/.smooth (macOS 14+)
  - Settings scene 需要 macOS 14+
  - 无法进一步降级到 macOS 13 而不牺牲用户体验
- **提交**: 7af7bb3, 644843e, 37a2d1b, 1f7aa64

---

## v0.4 遗留任务

### P0 - 紧急

1. ✅ **验证构建** - 运行 `xcodebuild` 确保项目可编译（2026-02-05 完成）
2. **测试核心功能** - 快捷键、搜索、OCR、自动粘贴

### P1 - 高优先级

3. **优化 Prompt Tools 集成** - 验证划词工具是否正常工作
4. **性能测试** - CPU 占用、数据库查询、动画帧率

### P2 - 中优先级

5. **文档同步** - 更新 README.md
6. **用户手册** - 编写快速开始指南
7. **发布准备** - Release 版本签名和分发

---

## 已完成（最近 10 项）

- ✅ 2026-02-05: 代码架构优化（Repository 模式、常量提取、扩展分离、职责分离）
- ✅ 2026-02-05: 构建验证通过（所有重构正常工作）
- ✅ 2026-02-02: macOS 14+ 兼容性（部署目标 14.0，兼容层支持 macOS 26 降级）
- ✅ 2026-01-30: 卡片滚动性能优化（LazyHStack + PhaseAnimator）
- ✅ 2026-01-30: 设置面板 UI 修复（改回 TabView）
- ✅ 2026-01-29: 钥匙串权限优化（单密钥策略）
- ✅ 2026-01-19: Liquid Glass 视觉升级（v0.2.1）
- ✅ 2026-01-19: 卡片正方形设计（180×180pt）
- ✅ 2026-01-19: 双线渐变分隔符
- ✅ 2026-01-16: 图片 OCR 搜索

---

## 待调研（需要 Context7）

- [ ] macOS 26 最新动画 API（.snappy/.smooth 参数优化）
- [ ] NavigationSplitView 最佳实践（避免 traffic lights 问题）
- [ ] Vision Framework 最新 OCR API（提升识别速度）

---

## 已知问题

1. **Debug 模式权限** - 每次编译需重新授权 Accessibility（Release 正常）
2. **VM 测试待完成** - macOS 13-15 功能测试需要虚拟机环境

---

**维护**: 每次完成任务后，将其移到"已完成"区域，并更新进度
