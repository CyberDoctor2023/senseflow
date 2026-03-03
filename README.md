# SenseFlow

> SenseFlow 不是剪贴板工具，而是一个基于"输入流"的隐形 AI Agent。

![Version](https://img.shields.io/badge/version-0.5.0-blue)
![macOS](https://img.shields.io/badge/macOS-14.0%2B-green)
![Architecture](https://img.shields.io/badge/architecture-Clean%20Architecture-brightgreen)
![Apple Silicon](https://img.shields.io/badge/chip-Apple%20Silicon-black)

## 核心理念

我们利用"剪贴板"这一操作系统最底层的数据交换口，构建一个低用户可见面的智能体：

- **输入端**：捕捉用户的瞬间意图（划词 / 复制）
- **处理端**：后台 AI 转化信息，避免中转 chatbot GUI
- **输出端**：以最小打扰的方式交付结果（粘贴 / 替换）

## 设计哲学：低 SKU，避免功能腐败

借用零售业的隐喻 —— 商品 SKU 低 = 买手替用户做选择；功能 SKU 低 = 产品替用户做选择。

- **暴露选项是开发者的懒惰**，我们替用户做好选择
- **把复杂留在内部**，配置项压到最少
- **克制而非焦虑** —— 像 iOS 灵动岛一样收敛状态，而非堆砌入口

## 功能

### Memory：从碎片到上下文
- 剪贴板自动捕获（文本、图片）
- 底部悬浮窗 + Liquid Glass 效果 + 横向卡片浏览
- 实时搜索 + 图片 OCR 文本搜索
- 自动粘贴（一键回到目标应用）
- 敏感数据自动过滤

### Skill：Smart AI 意图识别
- 划词 / 复制触发 Smart AI
- AX Tree 实时覆盖截图 + 全屏截图，构建上下文
- 系统 Prompt + 用户 Prompt + 截图 → LLM 意图识别
- 基于光标位置的局部意图推断，自动推荐最匹配的 Prompt Tool

## 安装

从 [Releases](https://github.com/CyberDoctor2023/senseflow/releases) 下载最新 DMG：

1. 打开 DMG，将 `SenseFlow.app` 拖入 `/Applications`
2. 首次打开：右键 → 打开（未签名应用）
3. 授予 Accessibility 权限（用于自动粘贴，可选）

**系统要求**：macOS 14.0+，Apple Silicon（M1/M2/M3/M4）

## 使用

| 操作 | 方式 |
|------|------|
| 呼出历史 | `Cmd+Option+V`（可自定义） |
| 搜索 | 直接输入关键词 |
| 粘贴 | 点击卡片 |
| Smart AI | 划词后按快捷键 |
| 删除 | 悬停卡片 → 删除按钮 |
| 设置 | 菜单栏 → 设置 |

## 技术栈

SwiftUI + AppKit + SQLite + Vision OCR + Clean Architecture

## 许可证

Copyright © 2026 Jack. All rights reserved.
