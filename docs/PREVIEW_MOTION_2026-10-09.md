# 长按预览节奏调整

按用户确认的用途选择曲线，不将原生 API、自定义参数和平台预设混为一谈。

范围：长按准备恢复 easeInOut（放大 1.10，中心锚点，阈值 0.45s 不变）；预览展开使用 AppKit 命名 easeOut（0.32s）；收回保持 easeInEaseOut（返回 0.48s、滚动淡出 0.16s）。hover、预览源标记、指针起伏启停及分类按钮反馈用 SwiftUI smooth，无回弹。

保留滚轮惯性与原生弹性、教程回弹/阶段组织、文本/图片同一窗口动画、材质、编辑和草稿逻辑。没有新增计时器或动画驱动链路；暂不引入关键帧，当前两个阶段已有原生长按状态和窗口呈现边界。

验收：Release 构建；现有原生文档替换/草稿安全/滚动关闭回归；正常退出、备份并替换本地安装版，运行确认历史窗口可用。只改变曲线，不据此宣称性能改善或复刻苹果 Quick Look。既有 GitHub 预发布资产对应旧提交，本轮不静默改写已发布标签/安装包。

官方依据：Apple Doc MCP 已核验 Animation.easeInOut、smooth 及 CAMediaTimingFunction(name:)；平台工具职责参考 docs/MOTION_PLATFORM_2026-10-08.md。

## 验证与安装

- Release 与 Debug 构建通过，日志在 `out/2026-10-08-project-refactor/build-preview-motion*-2026-10-09.log`。安装使用优化后的 Release；原生回归使用 Debug 的 testable 模块。
- 既有文档回归完整通过一次，日志 `out/2026-10-09-preview-motion/document-stable.log`，包括全文、编辑/草稿、替换/关闭、鼠标惯性与反向滚动。另几次运行出现窗口状态断言/等待超时，记录全部保留；根因未确认，不能宣称稳定性已完全验证。排查用的测试修改已撤回，没有降低断言或修改生产生命周期来换取通过。
- 正常退出旧应用，备份到 `/Users/jack/Applications/senseflow-backups/2026-10-09/SenseFlow-before-preview-motion.app`，替换 `/Applications/SenseFlow.app` 并启动。签名严格校验通过；CUA 确认历史窗口和鼠标滚轮翻看可用。真实长按手感需实际体验，不以合成事件宣称视觉验收。
- 安装产物在 `out/2026-10-09-preview-motion/SenseFlow.app`；已发布的 GitHub 标签与安装包未改写。
