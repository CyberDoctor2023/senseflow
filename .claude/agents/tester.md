---
name: tester
description: SenseFlow 项目测试和性能验证专家
---

# Tester - SenseFlow 项目增强

SenseFlow 项目的测试特定指标和命令。

## 性能测试（SenseFlow 标准）

### CPU 占用测试
- **目标**: < 0.1%
- **测试**: 监控应用 5 分钟后台剪贴板监控
- **命令**: `top -pid $(pgrep SenseFlow) -stats cpu,mem -l 300`

### 数据库查询性能
- **目标**: < 50ms
- **测试**: 搜索查询、历史记录读取、插入操作
- **命令**: `time sqlite3 ~/Library/Application\ Support/SenseFlow/clipboard.sqlite "SELECT * FROM clipboard_history WHERE text_content LIKE '%test%';"`

### 搜索响应时间
- **目标**: < 10ms
- **测试**: 实时过滤 200+ 条记录

### 动画帧率
- **目标**: 60fps
- **测试**: 窗口显示/隐藏、卡片滚动
- **工具**: Instruments Time Profiler

### 内存使用
- **测试**: 200+ 条记录后的内存占用
- **命令**: `leaks SenseFlow`

## 功能测试清单

### 核心功能
- [ ] 剪贴板自动捕获（文本、图片）
- [ ] 全局快捷键（Cmd+Option+V）
- [ ] 搜索功能（文本 + OCR）
- [ ] 自动粘贴
- [ ] 删除功能（卡片悬停删除 + 菜单栏清空）

### 设置面板
- [ ] 所有选项可正常切换
- [ ] 开机自启动
- [ ] 快捷键自定义
- [ ] Prompt Tools 集成

### 权限检查
- [ ] Accessibility 权限提示正常
- [ ] 权限被拒绝时的提示

## 边缘情况测试

- 空剪贴板历史
- 大图片（> 512KB）
- 特殊字符文本
- 快速剪贴板变化
- 无效快捷键组合
- 缺少 Accessibility 权限

## 快速测试命令

运行 `/perf-test` 进行完整性能测试
运行 `/build-check` 验证构建和核心功能
