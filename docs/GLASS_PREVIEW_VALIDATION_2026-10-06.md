# 玻璃预览修订与验证

日期：2026-10-06。本次用户反馈优先于旧标题栏/文档工具栏设计。没有 Git 元数据；源文件备份和改动对照在 `../out/2026-10-06-glass-morph/`。

## 实际行为

- 文字/图片卡片从真实屏幕矩形起步，约380ms展开并移动至所在屏幕中央。预览只显示无边框、透明玻璃浮层，无系统红绿灯；关闭约240ms收回。显式按钮/Space固定预览，hover不抢key，点击正文才进入编辑。
- 图片后台按需解码至最大2048px预览，保留原图；浮层按比例适配，不允许误进入文字编辑或误弹草稿对话框。
- 卡片采用 macOS26+原生SwiftUI glassEffect(.regular.interactive())，文档表面采用原生glassEffect(.regular)。删除历史列表下面重复的大玻璃/灰色material叠层；独立卡片用GlassEffectContainer分组。编辑器/scroll/clip背景透明，外观设appearsActive偏好，未通过激活窗口抢焦点维持玻璃。
- 展开时玻璃轮廓/窗口几何变化，正文viewport保持最终尺寸；完成后正文淡入，真正手动resize时viewport才随窗口尺寸变化。Reduce Motion立即定位。原文、独立草稿、最新写入代次合同保持。
- 查找、字号、等宽选择、显式编辑按钮和文档工具栏已删除，点击正文自然编辑；只有来源、关闭及编辑时的必要复制/保存操作。相关find/display端口亦删除。
- 历史列表内普通垂直鼠标滚轮转横向滚动；已有横向触控板事件交给系统。仅作用于同一history窗口及viewport，正文垂直滚动、Cmd/Ctrl手势不拦截；滚动取消未固定hover候选。

## 已验证

- 最终无签名Debug构建成功：`../out/2026-10-06-glass-morph/build.log`；正式签名证书限制仍存在。
- focused验证通过：`../out/2026-10-06-glass-morph/verification.log`。包括修正后的摘要来自真实原文（UTF-8前缀，兼容SQLite摘要落在组合字符内部）、109k原文、1.35M正文完整性、原文不变、草稿落盘/恢复、异步保存竞争、IME不提交、undo/redo、OCR空结果/坏图，新增真实PNG的比例/无边框透明/图片不能文字编辑/无草稿对话框关闭验证。
- 同设备同隔离库43条长文，12轮热读取全文中位数7.61ms，修正后真实摘要中位数1.57ms。原始数据在 `../out/2026-10-06-glass-morph/verification/metrics.json`，替代上轮无效摘要表达式测量。压力显式载入计时不包含完整玻璃展开动画，不能称为视觉首屏或Release p95。
- 隔离体验加载14条实际记录，通过桌面工具发送垂直滚动；AX可见列表出现后续卡片变化。截图服务随后返回ScreenCaptureKit -3812，尚未取得完整鼠标hover轨迹/动画录像或帧率实测，不能据此宣称动画性能已达预算。
- 旧应用正常退出请求已成功，未强制杀进程。重启仅运行开发构建，不替换 `/Applications` 已安装版本。

## 官方事实与限制

Apple Doc MCP已查询 [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))（macOS26+）、[appearsActive](https://developer.apple.com/documentation/swiftui/environmentvalues/appearsactive)（活跃外观偏好，不保证所有系统状态恒定）、[NSWindow.setFrame](https://developer.apple.com/documentation/appkit/nswindow/setframe(_:display:animate:))、[NSAnimationContext](https://developer.apple.com/documentation/appkit/nsanimationcontext/runanimationgroup(_:completionhandler:))、[本地事件监视](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:))。不依赖前端动画库。

玻璃实际透光受背后内容、系统外观和辅助功能影响；本轮未修改系统透明度/辅助功能设置。后续以用户实际设备体验验证失焦外观与丝滑程度，并补Release帧率/输入延迟、多屏和真实输入法证据。
