# 顶部工具拖放

目标：左侧保留筛选，右侧以「工具」标识圆形工具目标；将文字卡片拖入目标，松开执行对应工具，使用完整卡片文字，不先改写剪贴板。目标进入时放大、抬升、阴影反馈，离开恢复；执行期间禁用重复提交，错误可见。图片/录屏不进入纯文本工具。

快捷键：保留全局呼出 Command+Shift+V；顶部工具按当前显示顺序提供窗口内 Command+Shift+1…9。已有用户自定义全局键不擅自覆盖。编号与工具提示对应，不增加新的全局数字注册。

非目标：本次不修改预置 prompt 和商业化模型服务，不将图片伪装成文字。

验收：左右分区清晰；拖放全文只执行一次；取消不执行；加载失败提示；设置修改后再次呼出刷新；构建、原生 UI 查看和实际拖放验证。吸附效果的视觉验收需实际运行，不能以编译代替。

引用：Apple DropDelegate https://developer.apple.com/documentation/swiftui/dropdelegate （Apple Doc MCP 已查询）；Paste 窗口内快捷键 https://pasteapp.io/help/keyboard-shortcuts 。

## 实现与验证
- 顶部左右分区；右侧最多九个工具圆形目标，名称/编号提示，窗口内 Command+Shift+1…9；再次呼出从仓库刷新。
- 沿用原生卡片 drag-local pasteboard 全文，SwiftUI onDrop 异步读取 UTF-8；只接受文字，松开后执行，重复提交禁用。成功复制结果，不自动粘贴。
- 吸附反馈当前是目标圆球放大/抬升/阴影；尚未实现卡片向圆球变形融合，不能宣称原生 Liquid Glass 卡片吸附已完成。
- build-tool-drop.log：BUILD SUCCEEDED；git diff --check 通过。旧应用备份后安装并启动，进程 28527。
- 原生 UI 验证受阻：cua.getApp 返回 noWindowsAvailable，cua.getState 超时并重置。真实拖放命中、快捷键窗口作用域、首次 AI 请求与吸附视觉仍待实际运行验收，未请求模型以避免发送真实历史文字。
