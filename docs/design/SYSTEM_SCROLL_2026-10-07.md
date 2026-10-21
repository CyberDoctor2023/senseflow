# 系统横向滚动与末尾可达

目标：删除手动NSClipView位置clamp，恢复原生阻力/结束回弹；稳定滚到最后一张卡片，并在接近页尾时加载后续摘要。

实现方向：SwiftUI当前ScrollPosition + scrollTargetLayout提供位置/重开复位；onScrollGeometryChange依据实际视口接近末尾请求后页，替代单个卡片task触发。窗口原生路由继续隔离预览正文。以NSEvent实际像素/行delta构造横向标准原生滚轮事件；真实手势保留phase/momentum，离散鼠标事件组成短滚动手势并发送ended，阻力/回弹交给NSScrollView，不另写阻力曲线或内容offset。

非目标：改预览/卡片按压、重做拖动、恢复数据保留上限。pin仍固定当前数据，不追加页。

验证：focused build；真实生产窗口事件入口普通行/精确像素移动、结束阶段与边缘返回、最后卡片完整可见及继续分页、现有文档回归。物理手感需实机确认，不用合成事件宣称与苹果完全一致。

引用：Apple Doc MCP确认ScrollPosition/scrollPosition(macOS15)、onScrollGeometryChange(macOS15)、scrollTargetLayout(macOS14)、NSScrollView.horizontalScrollElasticity。首次混合大小写geometry路径404，完整规范路径读取成功。

验证结果：focused Debug build成功；同一生产窗口路由的scroll-only验证完成（out/2026-10-07-system-scroll/scroll-verification.log）。行滚轮72pt，精确滚轮17pt；204条记录经滚动几何自动追加第二页并完整到达末尾，末尾留白28.5pt；原生越界拉伸可观测，释放后距约束边界0.5pt。边界测量允许1pt像素对齐误差。验证使用隔离数据库和真实NSPanel/SwiftUI列表，但合成输入不代表物理设备手感。

完整文档回归未完成：首次等待超时，随后一次停在异步保存竞争场景；已保存进程sample，主线程在正常run loop，后台有Vision请求等待，尚未确认具体等待根因。滚动专项与该场景分开，不能宣称本轮完整回归通过。验证文件增加实时日志和超时调用行号，未删除该场景。
