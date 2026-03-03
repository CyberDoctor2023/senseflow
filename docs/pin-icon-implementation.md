# 钉子图标实现文档

> 创建日期: 2026-02-09
> 功能: 窗口固定功能的视觉实现

---

## 概述

钉子图标用于固定浮动窗口，防止失去焦点时自动隐藏。使用 SF Symbols `pin.fill` 图标，结合专业级 hover 动画和状态反馈。

---

## 设计理念

### 视觉隐喻
- **未钉状态**: 45° 斜向，表示"准备钉入"
- **已钉状态**: 0° 垂直向下，表示"已钉牢"
- **Hover 效果**: 轻微上移 + 放大，表示"可以拔起来"

### 交互反馈
1. **Hover**: 放大 15% + 上移 2px + 颜色变亮
2. **点击**: 快速旋转 + 缩放动画（"钉入"效果）
3. **状态切换**: 流畅的 spring 动画

---

## 实现细节

### 文件位置
```
SenseFlow/Views/Components/PinIconView.swift
```

### 核心代码

```swift
struct PinIconView: View {
    let isPinned: Bool
    let size: CGFloat

    @State private var isHovered = false
    @State private var isAnimating = false

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: size))
            // 颜色：未钉=灰色，已钉=深色，hover=更亮
            .foregroundStyle(foregroundColor)
            // 旋转角度：未钉=45°斜向，已钉=0°垂直
            .rotationEffect(.degrees(isPinned ? 0 : 45))
            // Hover: 轻微上移（"拔起来"）
            .offset(y: isHovered && !isPinned ? -2 : 0)
            // Hover: 轻微放大
            .scaleEffect(isHovered ? 1.15 : 1.0)
            // "钉下去"的动画
            .scaleEffect(isAnimating ? 0.8 : 1.0)
            .rotationEffect(.degrees(isAnimating ? -15 : 0))
            // 流畅的动画
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPinned)
            // Hover 检测
            .onHover { hovering in
                isHovered = hovering
            }
            // "钉下去"动画触发
            .onChange(of: isPinned) { newValue in
                if newValue {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        isAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isAnimating = false
                        }
                    }
                }
            }
            // 扩大点击区域
            .contentShape(Rectangle().inset(by: -8))
    }

    private var foregroundColor: Color {
        if isHovered {
            return isPinned ? .primary.opacity(0.9) : .secondary.opacity(0.8)
        } else {
            return isPinned ? .primary : .secondary.opacity(0.6)
        }
    }
}
```

---

## 使用方法

### 基本用法

```swift
@State private var isPinned: Bool = false

Button(action: {
    isPinned.toggle()
    FloatingWindowManager.shared.isPinned = isPinned
}) {
    PinIconView(isPinned: isPinned, size: 16)
}
.buttonStyle(.plain)
```

### 集成到窗口管理器

```swift
// FloatingWindowManager.swift
var isPinned = false

// 窗口失去焦点时检查
guard !isPinned else { return }  // 固定时不自动隐藏
```

---

## 动画参数

### Hover 动画
```swift
.scaleEffect(isHovered ? 1.15 : 1.0)  // 放大 15%
.offset(y: isHovered && !isPinned ? -2 : 0)  // 上移 2px
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
```

### 钉下去动画
```swift
// 第一阶段: 快速缩小 + 旋转
withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
    isAnimating = true  // scale: 0.8, rotation: -15°
}

// 第二阶段: 回弹（0.15s 后）
withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
    isAnimating = false  // scale: 1.0, rotation: 0°
}
```

### 旋转角度
```swift
.rotationEffect(.degrees(isPinned ? 0 : 45))  // 未钉=45°，已钉=0°
```

---

## 视觉状态

| 状态 | 旋转角度 | 颜色 | 透明度 | 说明 |
|------|---------|------|--------|------|
| 未钉 | 45° | secondary | 0.6 | 斜向，轻盈感 |
| 未钉 + Hover | 45° | secondary | 0.8 | 变亮，上移 2px |
| 钉下去中 | 45° → 0° | - | - | 旋转 -15° + 缩放 0.8 |
| 已钉 | 0° | primary | 1.0 | 垂直，深色，"钉牢" |
| 已钉 + Hover | 0° | primary | 0.9 | 轻微变暗 |

---

## 点击区域

```swift
.contentShape(Rectangle().inset(by: -8))
```

- 视觉大小: `size × size`
- 实际点击区域: `(size + 16) × (size + 16)`
- 比视觉大小大 **16px**，易于点击

---

## 技术亮点

### 1. 硬件加速
- 使用 `transform` 属性（scale, rotation, offset）
- 使用 `opacity` 属性
- 避免触发 layout reflow

### 2. 流畅动画
- Spring 动画提供自然的物理效果
- `response: 0.3` - 快速响应
- `dampingFraction: 0.6` - 适度回弹

### 3. 无障碍支持
- 使用系统 SF Symbol
- 自动适配深色/浅色模式
- 符合 Apple 设计规范

---

## 最佳实践

### ✅ 推荐
- 使用 SF Symbols 保证系统一致性
- 动画时长 < 0.5s，避免干扰用户
- 扩大点击区域提升易用性
- 使用 spring 动画模拟真实物理

### ❌ 避免
- 过度夸张的动画
- 动画时长 > 1s
- 复杂的自定义图形（性能差）
- 忽略无障碍支持

---

## 参考资料

- [Apple SF Symbols](https://developer.apple.com/sf-symbols/)
- [WWDC24: Create custom hover effects](https://developer.apple.com/videos/play/wwdc2024/10152/)
- [SwiftUI Animation Best Practices](https://designcode.io/swiftui-handbook-hover-effects/)
- [Hover.css - Button Hover Effects](https://ianlunn.github.io/Hover/)

---

## 版本历史

### v1.0 - 2026-02-09
- ✅ 初始实现（自定义圆形钉子）
- ✅ 基础点击动画

### v2.0 - 2026-02-09
- ✅ 升级为 SF Symbols `pin.fill`
- ✅ 添加 Hover 效果（放大 + 上移）
- ✅ 优化动画（旋转 + 缩放）
- ✅ 扩大点击区域

---

*文档结束*
