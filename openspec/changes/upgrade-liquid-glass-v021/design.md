# Liquid Glass v0.2.1 升级设计文档

## 概述

升级应用视觉效果到 macOS 26 最新 Liquid Glass 设计语言，使用最新的系统 API 和设计规范。

## 技术决策

### 1. macOS 版本兼容策略

**决策**: 主面板最低支持 macOS 12.0，设置窗口最低支持 macOS 14.0，使用运行时检测提供降级方案

**理由**:
- macOS 26 引入了 SwiftUI `.glassEffect()` 修饰符（Liquid Glass 效果）
- macOS 14-25 支持 `NavigationSplitView`（设置窗口需要）
- macOS 12-13 使用 SwiftUI 材质背景（`.ultraThinMaterial` 等）作为降级方案
- 向后兼容可确保现有用户不受影响

**实现**:
```swift
if #available(macOS 26.0, *) {
    // 使用 SwiftUI .glassEffect()
    view.glassEffect(.regular)
} else {
    // 降级到 SwiftUI 材质背景
    view.background(.ultraThinMaterial)
}
```

### 2. 背景材质选择

#### 主面板背景

**决策**: macOS 26 使用 `.glassEffect(.regular)`，早期版本使用 `.background(.ultraThinMaterial)`

**对比方案**:
| SwiftUI 材质 | 模糊强度 | 透明度 | 适用场景 |
|------|---------|--------|---------|
| `.ultraThin` | 低 | 高 | 轻量级浮窗 |
| `.thin` | 中低 | 中高 | 通知、提示 |
| `.regular` | 中 | 中 | 侧边栏、面板 |
| `.thick` | 高 | 低 | **主内容区域** ✅ |
| `.ultraThick` | 极高 | 极低 | 模态对话框 |

**macOS 26 Liquid Glass**:
| Glass 变体 | 对应材质 | 特性 |
|------|---------|--------|
| `.glassEffect(.regular)` | 类似 `.thickMaterial` | **推荐，主面板** ✅ |
| `.glassEffect(.clear)` | 类似 `.thinMaterial` | 轻量层级，卡片 |

**选择理由**:
- 主面板需要承载大量卡片内容，需要足够的背景区分度
- `.glassEffect(.regular)` / `.thickMaterial` 提供最佳的内容可读性
- 符合系统级应用（Dock、控制中心）的材质标准

#### 卡片背景

**决策**: macOS 26 使用 `.glassEffect(.clear)`，早期版本使用 `.background(.thinMaterial)`

**理由**:
- 卡片需要在主面板上形成层次对比
- `.glassEffect(.clear)` / `.thinMaterial` 提供轻量感，避免过度厚重
- 分层材质增强视觉分离（参考 macOS 系统卡片设计）

### 3. 动画参数调优

**决策**: 采用 SwiftUI 现代动画曲线

| 动画 | 时长 | 缓动函数 | 位移/缩放 |
|------|------|---------|----------|
| 主面板显示 | 0.4s | .snappy(duration: 0.4, extraBounce: 0.0) | 上移 30pt |
| 主面板隐藏 | 0.3s | .smooth(duration: 0.3, extraBounce: 0.0) | 下移 30pt + 淡出 |
| 卡片入场 | 0.5s | .snappy(duration: 0.5, extraBounce: 0.15) | 缩放 0.9→1.0 |
| 卡片悬停 | 0.25s | .snappy(duration: 0.25, extraBounce: 0.0) | 缩放 1.05x |

**调优原则**:
- 使用 `.snappy` / `.smooth` 替代传统 spring 动画（macOS 10.15+ 可用）
- 显示动画略慢（0.4s），给用户足够感知时间
- 隐藏动画较快（0.3s），减少等待感
- 卡片入场有微弱弹性（extraBounce: 0.15），更生动
- 卡片延迟入场（每个 +0.1s），形成波浪效果

### 4. 圆角半径标准化

**决策**: 统一使用 20pt 圆角

**依据**: macOS 26 系统级应用圆角标准
- 系统应用（设置、通知中心）：20pt
- 小组件、控件：12pt
- 按钮：8pt

**应用范围**:
- 主面板: 20pt
- 卡片容器: 20pt
- 搜索框: 8pt（小控件）

### 5. 阴影参数

**决策**: 卡片使用强阴影增强层次

```swift
.shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
```

**理由**:
- Liquid Glass 设计强调"悬浮感"
- 阴影半径 8pt 符合系统标准（macOS 设计指南）
- 垂直偏移 4pt 模拟自然光照

### 6. API 选择

#### 毛玻璃效果

**macOS 26+**: SwiftUI `.glassEffect()` 修饰符
```swift
// 主面板背景
view.glassEffect(.regular)

// 卡片背景
view.glassEffect(.clear)

// 带色调的玻璃效果
view.glassEffect(.regular.tint(.blue))

// 性能优化：合并多个玻璃效果
GlassEffectContainer {
    ForEach(cards) { card in
        CardView(card)
            .glassEffect(.clear)
    }
}
```

**macOS 12-25**: SwiftUI 材质背景（降级方案）
```swift
// 主面板背景
view.background(.ultraThinMaterial)

// 卡片背景
view.background(.thinMaterial)
```

#### 文本样式

**统一使用**: `.foregroundStyle()` 替代已弃用的 `.foregroundColor()`

#### 动画

**使用**: `.animation(.snappy(duration:extraBounce:), value:)` 和 `.animation(.smooth(duration:extraBounce:), value:)`
- 避免全局动画，明确绑定到状态值
- macOS 10.15+ 可用（不是 macOS 26 新功能）

## 兼容性矩阵

| macOS 版本 | 主面板效果 | 卡片效果 | 动画 | 功能完整性 |
|-----------|-----------|---------|------|-----------|
| 26.0+ | .glassEffect(.regular) | .glassEffect(.clear) | .snappy/.smooth | 100% |
| 14.0-25.x | .background(.ultraThinMaterial) | .background(.thinMaterial) | .snappy/.smooth | 95% (视觉降级) |
| 12.0-13.x | .background(.ultraThinMaterial) | .background(.thinMaterial) | .snappy/.smooth | 90% (设置用TabView) |

## 性能考虑

### 材质性能

- SwiftUI `.glassEffect()` 使用 GPU 加速，性能优于传统 `NSVisualEffectView`
- `.background(.material)` 同样使用 GPU 加速
- 实时模糊半径 < 30pt，保证 60fps 流畅度

### 动画性能

- `.snappy` 和 `.smooth` 使用 SwiftUI 动画系统，硬件加速
- 避免透明度 + 位移同时动画（GPU 压力）
- 卡片延迟入场总时长控制在 2s 内（20 卡片 × 0.1s）

## 用户体验影响

### 视觉改进

- ✅ 更强的层次感（`.glassEffect(.regular)` vs `.glassEffect(.clear)` 材质对比）
- ✅ 更自然的动画（符合物理直觉）
- ✅ 更现代的系统一致性（macOS 26 设计语言）

### 兼容性

- ✅ macOS 12+ 用户无功能损失
- ⚠️ macOS 12-13 用户设置窗口使用 TabView（NavigationSplitView 需要 macOS 14+）
- ⚠️ macOS 12-25 用户视觉效果降级到材质背景（可接受）

## 测试计划

### 视觉回归测试

- [ ] macOS 26: 验证 `.glassEffect()` 效果
- [ ] macOS 14-25: 验证降级到 `.background(.material)`
- [ ] macOS 12-13: 验证最低版本兼容性（设置使用 TabView）

### 动画性能测试

- [ ] 200 卡片入场动画 FPS 测试（目标 60fps）
- [ ] 频繁显示/隐藏主面板压力测试
- [ ] 内存占用监控（材质缓存）

### 用户测试

- [ ] A/B 测试：新动画 vs 旧动画（用户偏好）
- [ ] 可读性测试：`.glassEffect(.regular)` 材质下文本清晰度

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| macOS 26 API 不稳定 | 高 | 保留 macOS 15 降级方案 |
| 性能回归 | 中 | 动画参数可配置，支持关闭 |
| 用户反馈负面 | 低 | 提供"经典模式"开关 |

## 参考资料

- [macOS 26 Human Interface Guidelines - Materials](https://developer.apple.com/design/human-interface-guidelines/macos/visual-design/materials/)
- [SwiftUI Glass Effect Documentation](https://developer.apple.com/documentation/swiftui/view/glasseffect)
- [SwiftUI Animation - snappy/smooth](https://developer.apple.com/documentation/swiftui/animation)
- [WWDC 2026: What's New in SwiftUI](https://developer.apple.com/videos/wwdc2026/)
