# 平台动效替换合同

范围：历史滚动 A/B、卡片反馈、预览窗口、主窗口及教程手势/弹起。

删除固定频率 Timer 惯性与手写指数衰减，使用 NSView.displayLink 与 SwiftUI.Spring.smooth 求解器；保留设备原生 momentum 和 NSScrollView 弹性，不叠加系统惯性。窗口自定义贝塞尔改用 CAMediaTimingFunction 系统名称；教程抛物线回弹改用 Spring 预设；手势自定义 timingCurve 改 smooth。已有 easeIn/easeOut/easeInOut、phaseAnimator、visualEffect、glassEffect 属于系统 API，保留。

普通鼠标惯性、Dock 波形、长按阈值没有可直接套用的公开预设。事件适配、移动距离、阈值、波形为产品选择，不称为 Apple 官方规范。

非目标：改变短按粘贴/长按预览、A/B 选择、数据库、权限或玻璃底色；不替换业务轮询 Timer。

完成条件：focused build；原生滚动释放、反向、边缘、末卡回归；原生滚动场景进程 CPU 实测；正常退出、备份替换并启动。未测单帧耗时，不宣称无性能影响或帧率提升。

官方依据（Apple Doc MCP 已查询）：

- [NSView.displayLink](https://developer.apple.com/documentation/appkit/nsview/displaylink(target:selector:))：与视图所在显示器同步。
- [Spring](https://developer.apple.com/documentation/swiftui/spring)：系统 spring 预设及按时间计算位置/速度。
- [Animation.smooth](https://developer.apple.com/documentation/swiftui/animation/smooth)：无回弹的系统 spring 动画。
- [horizontalScrollElasticity](https://developer.apple.com/documentation/appkit/nsscrollview/horizontalscrollelasticity)：原生弹性。

首次写入规格的 shell Python 因输入编码失败，随后通过结构化补丁保存本合同。

释放断言发现：自造 momentum 事件经 scrollWheel 调用不会继续移动，旧 focused 测试未断言释放后的位移。删除自造惯性事件路径。普通鼠标改为 Spring 位置增量经 NSClipView.scroll / constrainBoundsRect / reflectScrolledClipView 更新；到边界停止，实际输入的越界回弹仍交给 NSScrollView。原生设备 momentum 继续原样路由，不添加第二套。

## 审查结果

| 区域 | 替换结果 |
| --- | --- |
| 鼠标补充惯性 | NSView Display Link、Spring.smooth 位置/速度、NSClipView 原生边界约束 |
| 主窗口及预览开合 | NSAnimationContext + 系统 easeInEaseOut，删除自定义控制点 |
| 教程弹起及反弹 | Spring.snappy / Spring.bouncy，删除贝塞尔与多段抛物线 |
| 教程触控板手势 | PhaseAnimator + Animation.smooth，删除自定义 timingCurve |
| 卡片 hover / 长按 | Animation.snappy / smooth，保留阈值与中心放大 |
| pin 反馈 | SymbolEffect.bounce + snappy，删除手动延迟回弹状态 |
| 菜单栏反馈 | PhaseAnimator + snappy，删除重复 Timer |
| 筛选、退场、设置渐变 | 已使用系统缓入缓出/转场 API，保留 |
| Liquid Glass | 保留系统 glassEffect / GlassEffectContainer，未改变材质 |
| B 模式指针波形 | 保留 visualEffect，公开 API 无 Dock/台前调度波形预设，标为产品设计 |

displayLink 同步屏幕刷新；Spring 按真实时间求位置与速度，不以固定帧数积分。视图禁用、拆卸、隐藏、反向输入及边界都会结束补充惯性。减少动态效果不启动惯性。长按的一次性识别 Timer 与阅读/剪贴板业务 Timer 不属于逐帧动画，没有为了替换而删除。

补充官方 API：[NSClipView.scroll](https://developer.apple.com/documentation/appkit/nsclipview/scroll(to:))、[constrainBoundsRect](https://developer.apple.com/documentation/appkit/nsclipview/constrainboundsrect(_:))、[系统曲线](https://developer.apple.com/documentation/quartzcore/camediatimingfunction/init(name:))、[SymbolEffect](https://developer.apple.com/documentation/swiftui/view/symboleffect(_:options:value:))。均通过 Apple Doc MCP 查询。本会话没有可调用的官方 Xcode bridge，沿用工程已核验的 xcodebuild 链。

## 验证证据

- `build-stage29.log` 保留 Spring 数字类型推断失败；修正显式 Double 后 `build-stage29-verified.log` 构建成功。
- `scroll-stage29.log` 保留惯性释放位移 0 的失败；替换事件路径后 `scroll-stage29-final.log` 释放移动 41.94pt，反向断言误用同步读取失败。按 AppKit 下一帧读取（25ms）后 `scroll-stage29-reverse.log` 全部通过：释放移动 42.02pt、反向 -48pt、原生弹性回到边界、末卡 28pt 边距及分页。
- `scroll-stage28-comparison.log` 同设备加载上版已安装 dylib，新增释放断言失败，位移 0pt。不能用旧回归通过证明旧版惯性有效。
- 同一滚动脚本旧版释放阶段进程 CPU 0.0873s / wall 0.6892s；新版 0.0551s / wall 0.7000s，完整场景 0.2758s / wall 3.1051s。旧版实际没有惯性移动，工作量不同且单次数据有噪声，不能据此宣称性能提升。未测 GPU/合成器和单帧耗时。
- `document-stage29.log` 完整原生文档回归通过：预览替换、滚动收起、原文/草稿/保存、编辑和错误恢复；测试隔离数据库，未修改真实历史。
- `tutorial-stage29.log` 原生教程显示/隐藏、左右阶段、预览、编辑另存、筛选、重开及关闭后不复活通过；外部剪贴板写入与粘贴为 0。物理输入、布局和主观曲线手感仍需单独体验。
- 运行版正常退出后备份 `SenseFlow-before-stage29.app`，签名验证成功并替换。新版 PID 60889，CUA 确认历史窗口/卡片加载。部署初次 CUA 观察超时，进程已启动，重绑定同一进程成功，没有重复启动或强杀。
