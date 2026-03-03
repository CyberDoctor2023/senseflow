# SenseFlow

一个高效的 macOS 剪贴板管理器，支持自动捕获、快捷键呼出、横向卡片展示、自动粘贴、图片 OCR 搜索、AI 驱动的 Prompt Tools。

![Version](https://img.shields.io/badge/version-0.4.1-blue)
![macOS](https://img.shields.io/badge/macOS-14.0%2B-green)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![Architecture](https://img.shields.io/badge/architecture-Clean%20Architecture-brightgreen)

## ✨ 功能特性

- 🎯 **自动捕获**: 后台自动保存剪贴板历史（文本、图片）
- ⌨️ **快捷键呼出**: `Cmd+Option+V` 快速呼出历史窗口（可自定义）
- 🎨 **横向卡片**: 底部悬浮窗 + Liquid Glass 效果 + 横向滚动
- 🔍 **智能搜索**: 实时搜索文本、应用名称、图片内容（OCR）
- 🔑 **快捷键自定义**: 自定义全局快捷键，实时冲突检测
- 🗑️ **删除功能**: 卡片悬停删除按钮 + 清空历史
- 🖼️ **图片 OCR**: 自动识别图片文字，支持搜索图片内容
- ⚙️ **设置面板**: 快捷键/历史上限/自启动/应用过滤
- 🚀 **自动粘贴**: 点击卡片自动粘贴到目标应用（可选）
- 🔒 **隐私保护**: 自动过滤密码管理器 + 自定义应用过滤列表
- 💾 **智能存储**: SQLite 数据库，支持 50-500 条历史记录，自动去重
- ⚡ **高性能**: CPU 占用 < 0.1%，流畅 60fps 动画

## 📸 截图

（待添加）

## 🔧 系统要求

- **操作系统**: macOS 14.0 (Sonoma) 或更高版本
- **开发工具**: Xcode 15.0+ （开发需要）
- **Swift 版本**: 5.9+

## 💻 技术栈

- **UI 框架**: SwiftUI + AppKit（窗口管理）
- **视觉效果**: NSGlassEffectView（macOS 15+ Liquid Glass）
- **数据库**: [SQLite.swift](https://github.com/stephencelis/SQLite.swift)
- **剪贴板**: NSPasteboard API
- **快捷键**: Carbon EventHotKey API
- **自动粘贴**: CGEvent（需要 Accessibility 权限）
- **OCR 识别**: Vision Framework (VNRecognizeTextRequest)
- **开机自启**: SMAppService (macOS 13+)

## 🏗️ 架构设计

本项目采用 **Clean Architecture**（整洁架构），实现业务逻辑与框架解耦，提高可测试性和可维护性。

### 架构层次（依赖方向：外层 → 内层）

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (表现层)                             │
│  SwiftUI Views + @EnvironmentObject                     │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Coordinator Layer (协调器层)                            │
│  协调多个 Use Case，处理 UI 请求                          │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Use Case Layer (用例层)                                 │
│  实现业务场景，编排服务                                    │
└─────────────────────────────────────────────────────────┘
                        ↓ 依赖
┌─────────────────────────────────────────────────────────┐
│  Port Layer (端口层 - 接口定义)                           │
│  定义业务逻辑需要的能力                                    │
└─────────────────────────────────────────────────────────┘
                        ↑ 实现
┌─────────────────────────────────────────────────────────┐
│  Adapter Layer (适配器层 - 接口实现)                      │
│  将外部框架适配到接口                                      │
└─────────────────────────────────────────────────────────┘
                        ↓ 调用
┌─────────────────────────────────────────────────────────┐
│  Infrastructure Layer (基础设施层)                        │
│  外部框架和系统 API                                        │
└─────────────────────────────────────────────────────────┘
```

**核心原则**:
- **依赖倒置**: 业务逻辑依赖接口，不依赖具体实现
- **单一职责**: 每个类只有一个变化原因
- **接口隔离**: 小而专注的接口定义
- **依赖注入**: 通过构造器注入依赖，便于测试

详细的架构教学请参考: [docs/ARCHITECTURE_TEACHING_GUIDE.md](docs/ARCHITECTURE_TEACHING_GUIDE.md)

## 📁 项目结构

```
SenseFlow/
├── Domain/                              # 领域层（核心业务规则）
│   ├── Protocols/                       # 接口定义（Port）
│   │   ├── AIServiceProtocol.swift      # AI 服务接口
│   │   ├── ClipboardReader.swift        # 剪贴板读取接口
│   │   ├── ClipboardRepository.swift    # 剪贴板仓库接口
│   │   ├── HotKeyRegistry.swift         # 快捷键注册接口
│   │   ├── NotificationServiceProtocol.swift  # 通知服务接口
│   │   └── PromptToolRepository.swift   # 工具仓库接口
│   ├── ValueObjects/                    # 值对象
│   │   ├── ClipboardContent.swift       # 剪贴板内容
│   │   ├── KeyCombo.swift               # 快捷键组合
│   │   └── ToolID.swift                 # 工具 ID
│   └── Errors/                          # 领域错误
│       └── PromptToolError.swift        # 工具错误定义
├── UseCases/                            # 用例层（应用业务规则）
│   ├── PromptTool/                      # Prompt 工具用例
│   │   ├── ExecutePromptTool.swift      # 执行工具
│   │   └── RegisterToolHotKey.swift     # 注册快捷键
│   └── SmartAI/                         # Smart AI 用例
│       └── AnalyzeAndRecommend.swift    # 分析推荐
├── Coordinators/                        # 协调器层（编排用例）
│   ├── PromptToolCoordinator.swift      # 工具协调器
│   └── SmartToolCoordinator.swift       # Smart AI 协调器
├── Adapters/                            # 适配器层（接口实现）
│   ├── Services/                        # 服务适配器
│   │   ├── OpenAIServiceAdapter.swift   # OpenAI 适配器
│   │   ├── NSPasteboardAdapter.swift    # 剪贴板适配器
│   │   ├── UserNotificationAdapter.swift # 通知适配器
│   │   ├── CarbonHotKeyAdapter.swift    # 快捷键适配器
│   │   └── SystemContextCollector.swift # 系统上下文收集
│   └── Repositories/                    # 仓库适配器
│       └── SQLitePromptToolRepository.swift  # SQLite 仓库
├── Infrastructure/                      # 基础设施层
│   └── DI/                              # 依赖注入
│       ├── DependencyContainer.swift    # DI 容器
│       ├── DependencyEnvironment.swift  # 环境对象
│       └── AppDependencies.swift        # 应用依赖
├── Managers/                            # 管理器模块（遗留代码）
│   ├── DatabaseManager.swift            # 数据库管理
│   ├── FloatingWindowManager.swift      # 悬浮窗管理
│   ├── HotKeyManager.swift              # 全局快捷键
│   ├── HotKeyPreferences.swift          # 快捷键配置
│   ├── AccessibilityManager.swift       # 权限管理
│   ├── AutoPasteManager.swift           # 自动粘贴
│   ├── BlobFileManager.swift            # 文件管理
│   ├── KeychainManager.swift            # 钥匙串管理
│   └── ScreenCaptureManager.swift       # 截图管理
├── Models/                              # 数据模型
│   ├── ClipboardItem.swift              # 剪贴板项模型
│   ├── ClipboardItemType.swift          # 类型枚举
│   ├── PromptTool.swift                 # Prompt 工具模型
│   └── SmartContext.swift               # Smart AI 上下文
├── Services/                            # 服务层
│   ├── ClipboardMonitor.swift           # 剪贴板监听
│   ├── AppIconCache.swift               # 应用图标缓存
│   ├── OCRService.swift                 # OCR 文字识别
│   └── AIService.swift                  # AI 服务（遗留）
├── Views/                               # 视图层
│   ├── ClipboardListView.swift          # 列表视图
│   ├── ClipboardCardView.swift          # 卡片视图
│   ├── VisualEffectView.swift           # 毛玻璃效果
│   ├── HotKeyRecorderView.swift         # 快捷键录制器
│   ├── SettingsView.swift               # 设置主视图
│   ├── PromptTools/                     # Prompt 工具视图
│   │   ├── PromptToolsView.swift        # 工具列表
│   │   └── PromptToolEditorView.swift   # 工具编辑器
│   └── Settings/                        # 设置子视图
│       ├── GeneralSettingsView.swift    # 通用设置
│       ├── ShortcutSettingsView.swift   # 快捷键设置
│       └── PrivacySettingsView.swift    # 隐私设置
├── AppDelegate.swift                    # 应用入口
├── main.swift                           # 主函数
└── Info.plist                           # 应用配置
```

## 🚀 快速开始

### 安装依赖

项目使用 Swift Package Manager，依赖会自动下载：

```bash
# 克隆项目
git clone https://github.com/your-username/SenseFlow.git
cd SenseFlow

# 用 Xcode 打开
open SenseFlow.xcodeproj
```

### 运行项目

1. 在 Xcode 中选择 `SenseFlow` scheme
2. 点击 Run (Cmd+R) 或选择 Product → Run
3. 首次运行需要授予 Accessibility 权限（可选）

### 使用方法

1. **启动应用** - 应用会在后台自动运行（菜单栏图标）
2. **复制内容** - 复制任意文本或图片
3. **呼出窗口** - 按 `Cmd+Option+V`（可在设置中自定义）
4. **搜索内容** - 输入关键词搜索文本、应用名称、图片内容
5. **选择内容** - 点击卡片
6. **自动粘贴** - 内容自动粘贴到目标应用（需授权）
7. **删除记录** - 悬停卡片显示删除按钮
8. **打开设置** - 菜单栏 → 设置（Cmd+,）

## 📋 功能详解

### 剪贴板自动捕获

- **支持类型**: 纯文本、图片（PNG、JPEG、TIFF）
- **轮询间隔**: 0.75 秒（低 CPU 占用）
- **去重机制**: SHA256 哈希，相同内容不重复存储
- **敏感过滤**: 自动过滤密码管理器数据（1Password、Bitwarden）
- **大文件处理**: 图片 >512KB 时分离存储
- **存储上限**: 200 条记录，FIFO 自动删除旧记录

### 历史窗口

- **位置**: 屏幕底部居中，距底部 20pt
- **样式**: 毛玻璃背景（NSVisualEffectView）
- **尺寸**: 自适应宽度，高度 300pt
- **动画**: 弹簧效果显示（0.4s），淡出隐藏（0.3s）
- **触发**: 快捷键、失焦自动隐藏

### 卡片展示

- **布局**: 横向滚动，最新记录在左侧
- **卡片尺寸**: 160 × 200pt，圆角 10pt
- **色条**: 文本蓝色 (#007AFF)，图片紫色 (#AF52DE)
- **交互**: 悬停放大 1.05x，点击写入剪贴板
- **时间标签**: 相对时间（刚刚、5分钟前、2小时前）

### 自动粘贴（可选）

- **实现方式**: 模拟 Cmd+V 按键（CGEvent）
- **焦点管理**: 自动切换回前一个应用
- **延迟优化**: 0.3 秒延迟，确保焦点切换
- **权限要求**: Accessibility 权限（首次使用时提示）
- **降级方案**: 未授权时手动粘贴

## 🔐 权限说明

### Accessibility 权限（可选）

**用途**: 实现自动粘贴功能

**授权方式**:
1. 点击卡片时弹出权限提示
2. 点击"打开系统设置"
3. 在"隐私与安全性" → "辅助功能"中勾选 SenseFlow

**不授权的影响**: 需手动按 Cmd+V 粘贴，其他功能正常使用

## 📊 性能指标

| 指标 | 数值 |
|------|------|
| CPU 占用（后台） | < 0.1% |
| 内存占用（200 条记录） | < 100MB |
| 数据库查询速度 | < 50ms |
| 窗口动画帧率 | 60fps |

## 🛠️ 开发文档

### 技术方案

详细的技术方案请查看 `spec/` 目录：

- [PRD v0.1](spec/PRD_v0.1.md) - 产品需求文档
- [技术参考文档](spec/TECHNICAL_REFERENCE.md) - 完整技术方案（UI、数据层、快捷键、自动粘贴、OCR 等）

### 开发进度

**当前版本**: v0.4.1

**v0.1 - 基础功能**
- [x] 项目初始化
- [x] 数据库管理器
- [x] 剪贴板监听服务
- [x] 悬浮窗口管理
- [x] UI 组件（卡片、列表）
- [x] 全局快捷键
- [x] 自动粘贴功能

**v0.2 - 增强功能**
- [x] 应用图标显示
- [x] 快捷键冲突检测
- [x] 搜索功能
- [x] 图片 OCR 识别
- [x] 快捷键自定义
- [x] 删除功能
- [x] 设置面板

**v0.3 - Prompt Tools**
- [x] Prompt 工具管理
- [x] 工具快捷键绑定
- [x] AI 文本处理
- [x] 工具编辑器

**v0.4 - Clean Architecture 重构**
- [x] 领域层设计（Protocols, Value Objects）
- [x] 用例层实现（ExecutePromptTool, RegisterToolHotKey）
- [x] 适配器层实现（NSPasteboard, OpenAI, Notification）
- [x] 依赖注入容器
- [x] 协调器层（PromptToolCoordinator, SmartToolCoordinator）
- [x] 单元测试（ExecutePromptTool 100% 覆盖）
- [x] 架构文档和教学注释

**v0.5 - 计划中**
- [ ] Smart AI 功能集成
- [ ] 完整的集成测试
- [ ] 性能优化

### 构建 Release 版本

```bash
xcodebuild -project SenseFlow.xcodeproj \
  -scheme SenseFlow \
  -configuration Release \
  clean build
```

## 🐛 已知问题

1. **Debug 模式权限问题**: 每次 Cmd+R 需要重新授权 Accessibility（Release 版本无此问题）
2. **设置面板需要 macOS 13.0+**: 低版本系统会提示升级

## 🙏 致谢

本项目参考了以下开源项目：

- [Maccy](https://github.com/p0deje/Maccy) - 剪贴板监听、数据存储、自动粘贴实现
- [SQLite.swift](https://github.com/stephencelis/SQLite.swift) - Swift 数据库封装

## 📄 许可证

Copyright © 2026. All rights reserved.

---

**开发者**: Jack
**邮箱**: your-email@example.com
**项目主页**: https://github.com/your-username/SenseFlow
