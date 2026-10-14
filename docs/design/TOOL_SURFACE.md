# 圆形控件表面规范

筛选与工具统一读取 SearchBarConfig.default：36pt 外形、16pt 图标、垂直基线为顶部区域中心；按下或出现不得通过改变布局高度挤动其他控件。

macOS 26 使用 regular.interactive 原生圆形玻璃；未选中图标 secondary、选中 primary。非支持版本 regularMaterial。沿用 Constants.SelectionFeedback 的 hover 尺寸和时长。工具拖放目标可额外放大至 1.16，表示松开执行，不意味着普通筛选选中态。

普通出现采用 matchedGeometry 与 easeInOut；背景不得参与覆盖历史内容的上层融合。拖动时唯有实际目的工具与拖动卡片参与同一个容器，其他工具与左侧筛选隔离。形变与内容载荷分离，不在指针移动中做 SQL、文件读取或图片解码。

验证分开记录：构建、静态基线/可读性、实际拖动融合、取消回程；构建通过不能代替后两项。

职责边界：ClipboardCardView 负责内容与原生按压/拖放源适配；CardDragPresentation.swift 独立负责工具几何协议、当前整卡呈现、唯一投递、取消收尾及其玻璃覆盖层。工具仓库和执行仍由现有协调器拥有，不复制工具模型或新增执行链。提取不改变动画参数与视觉行为；旧文件中的声明必须删除并同步 Xcode Sources 引用。验证为差异等价检查、工程成员检查、focused build；实际拖动仍须独立验收。
