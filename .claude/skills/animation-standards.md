# SenseFlow 动画标准

SenseFlow 项目的动画参数标准（macOS 26+）。

## 项目动画标准

所有动画必须符合以下参数以保持一致性和 60fps 性能。

### 动画参数表

| 场景 | 动画类型 | duration | extraBounce | 说明 |
|------|----------|----------|-------------|------|
| 窗口显示 | `.snappy` | 0.35 | 0.0 | Slide from bottom (30pt offset) + Fade in |
| 窗口隐藏 | `.snappy` | 0.35 | 0.0 | Slide to bottom (30pt offset) + Fade out |
| 卡片入场 | `.snappy` | 0.5 | 0.15 | 活泼，轻微弹跳 |
| 卡片悬停 | `.snappy` | 0.25 | 0.0 | 快速响应 |
| 布局调整 | `.smooth` | 0.4 | 0.0 | 微妙过渡 |

## 代码示例

```swift
// 窗口显示/隐藏动画（从底部滑入/滑出）
.offset(y: isWindowVisible ? 0 : 30)  // 底部滑入（30pt 偏移）
.opacity(isWindowVisible ? 1.0 : 0.0)
.animation(.snappy(duration: 0.35, extraBounce: 0.0), value: isWindowVisible)

// 卡片入场动画
.animation(.snappy(duration: 0.5, extraBounce: 0.15), value: scale)
    .scaleEffect(scale)
    .onAppear { scale = 1.0 }

// 卡片悬停动画
.scaleEffect(isHovered ? 1.05 : 1.0)
.animation(.snappy(duration: 0.25, extraBounce: 0.0), value: isHovered)

// 布局调整动画
.animation(.smooth(duration: 0.4, extraBounce: 0.0), value: layoutSize)
```

## 性能要求

- **目标帧率**: 60fps
- **测试工具**: Instruments Time Profiler
- **检测方法**: 运行 `/perf-test` 命令

## 一致性规则

- ❌ 禁止使用自定义参数，必须使用上表中的标准值
- ✅ 新增动画场景需先在此文档中定义标准参数
- ✅ 代码审查时检查动画参数是否符合标准
