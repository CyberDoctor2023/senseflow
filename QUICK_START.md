# 快速入门指南

## 🚀 5 分钟上手新架构

### 1. 理解核心概念

**协议（Protocol）= 合约**
```swift
// 协议定义"能做什么"，不关心"怎么做"
protocol WindowLayoutConfigurable {
    func calculateMainWindowFrame(for screen: NSScreen) -> NSRect
}
```

**依赖注入（DI）= 从外部传入依赖**
```swift
// ❌ 旧方式：内部创建依赖（紧耦合）
class Manager {
    let config = WindowLayoutConfig.default  // 硬编码
}

// ✅ 新方式：从外部注入依赖（松耦合）
class Manager {
    let config: WindowLayoutConfigurable
    init(config: WindowLayoutConfigurable = WindowLayoutConfig.default) {
        self.config = config
    }
}
```

---

### 2. 生产代码使用（零改动）

**现有代码继续工作，无需修改：**
```swift
// FloatingWindowManager 自动使用默认配置
let manager = FloatingWindowManager.shared

// 配置系统透明工作
manager.showWindow()  // 使用 layoutConfig 计算窗口位置
```

**如果需要自定义配置：**
```swift
// 创建自定义配置
var customBackground = BackgroundLayoutConfig.default
customBackground.cornerRadius = 30  // 修改圆角

let customConfig = WindowLayoutConfig(
    background: customBackground,
    cardArea: .default,
    topBackground: .default
)

// 注入自定义配置
let manager = FloatingWindowManager(layoutConfig: customConfig)
```

---

### 3. 编写测试（新能力）

**测试窗口计算逻辑：**
```swift
import Testing
@testable import SenseFlow

@Test("Window frame calculation")
func testWindowFrame() {
    // Arrange - 准备测试数据
    let config = WindowLayoutConfig.default
    let mockScreen = MockScreen(width: 1920, height: 1080)

    // Act - 执行被测试的代码
    let frame = config.calculateMainWindowFrame(for: mockScreen.screen)

    // Assert - 验证结果
    #expect(frame.width > 0, "窗口宽度应该大于 0")
    #expect(frame.height > 0, "窗口高度应该大于 0")
}
```

**使用 Mock 隔离测试：**
```swift
@Test("Manager uses injected config")
func testManagerWithMock() {
    // 创建 mock 配置（返回固定值）
    let mockConfig = MockWindowLayoutConfig.fixed(
        mainFrame: NSRect(x: 0, y: 0, width: 800, height: 240)
    )

    // 注入 mock
    let manager = FloatingWindowManager(layoutConfig: mockConfig)

    // 测试 manager 的行为（不依赖真实屏幕）
    // ...
}
```

**参数化测试（测试多个场景）：**
```swift
@Test("Gap calculation with different values", arguments: [2.0, 5.0, 10.0])
func testGap(gap: CGFloat) {
    var config = TopBackgroundLayoutConfig.default
    config.gapFromMainWindow = gap

    let frame = config.calculateWindowFrame(...)

    #expect(frame.origin.y == mainFrame.maxY + gap)
}
```

---

### 4. SwiftUI 集成（可选）

**在视图中使用环境值：**
```swift
import SwiftUI

struct MyView: View {
    @Environment(\.windowLayoutConfig) var layoutConfig

    var body: some View {
        VStack {
            Text("Corner Radius: \(layoutConfig.background.cornerRadius)")
            Text("Card Height: \(layoutConfig.cardArea.cardHeight)")
        }
    }
}
```

**在父视图中覆盖配置：**
```swift
MyView()
    .windowLayoutConfig(customConfig)  // 子视图自动获取
```

---

## 📝 常见场景

### 场景 1：修改配置参数

**需求：** 将主窗口与顶部窗口的间距从 2pt 改为 5pt

```swift
// 1. 修改配置文件
// SenseFlow/Models/TopBackgroundLayoutConfig.swift
static let `default` = TopBackgroundLayoutConfig(
    gapFromMainWindow: 5,  // 从 2 改为 5
    windowHeight: 100,
    cornerRadius: 20
)

// 2. 运行测试验证
// Tests/WindowLayoutConfigTests.swift
@Test("Gap is 5pt")
func testNewGap() {
    let config = TopBackgroundLayoutConfig.default
    #expect(config.gapFromMainWindow == 5)
}

// 3. 构建并运行
// xcodebuild build
```

---

### 场景 2：添加新配置项

**需求：** 添加底部工具栏配置

```swift
// 1. 创建新配置
// SenseFlow/Models/BottomBarLayoutConfig.swift
struct BottomBarLayoutConfig {
    let height: CGFloat
    let gap: CGFloat

    static let `default` = BottomBarLayoutConfig(
        height: 50,
        gap: 5
    )
}

// 2. 扩展 WindowLayoutConfig
extension WindowLayoutConfig {
    var bottomBar: BottomBarLayoutConfig {
        return BottomBarLayoutConfig.default
    }
}

// 3. 添加测试
@Test("Bottom bar height")
func testBottomBarHeight() {
    let config = WindowLayoutConfig.default
    #expect(config.bottomBar.height == 50)
}
```

---

### 场景 3：调试配置问题

**问题：** 窗口位置不正确

```swift
// 1. 编写测试重现问题
@Test("Window position bug reproduction")
func testWindowPositionBug() {
    let config = WindowLayoutConfig.default
    let screen = MockScreen(width: 1920, height: 1080)

    let frame = config.calculateMainWindowFrame(for: screen.screen)

    // 打印实际值
    print("Frame: \(frame)")

    // 验证预期
    #expect(frame.origin.y >= 0, "Y 坐标不应该是负数")
}

// 2. 运行测试找到问题
// 3. 修复代码
// 4. 再次运行测试验证修复
```

---

## 🎯 下一步行动

### 立即可做（5 分钟）

1. **运行现有测试**
   ```bash
   # 在 Xcode 中：Product > Test (⌘U)
   # 或命令行：
   xcodebuild test -project SenseFlow.xcodeproj -scheme SenseFlow
   ```

2. **查看测试覆盖率**
   - Xcode > Product > Test
   - 查看 Coverage 标签

3. **尝试修改配置**
   - 打开 `TopBackgroundLayoutConfig.swift`
   - 修改 `gapFromMainWindow` 为 5
   - 运行测试看是否通过

---

### 短期改进（1-2 天）

1. **配置测试 Scheme**
   ```
   Xcode > Product > Scheme > Edit Scheme
   > Test > 添加 SenseFlowTests target
   ```

2. **添加更多测试用例**
   - 边界条件测试（极小/极大屏幕）
   - 错误处理测试
   - 性能测试

3. **集成 CI/CD**
   ```yaml
   # .github/workflows/test.yml
   - name: Run tests
     run: xcodebuild test -project SenseFlow.xcodeproj -scheme SenseFlow
   ```

---

### 长期优化（1-2 周）

1. **提升测试覆盖率到 90%+**
   - 测试所有公共方法
   - 测试边界条件
   - 测试错误路径

2. **性能测试**
   ```swift
   @Test("Window calculation performance")
   func testPerformance() {
       let config = WindowLayoutConfig.default

       measure {
           for _ in 0..<1000 {
               _ = config.calculateMainWindowFrame(for: screen)
           }
       }
   }
   ```

3. **文档完善**
   - 为每个配置项添加注释
   - 创建架构决策记录（ADR）
   - 编写贡献指南

---

## 🐛 故障排查

### 问题：测试无法运行

**症状：** `xcodebuild test` 报错 "Scheme not configured for test"

**解决：**
```
1. 打开 Xcode
2. Product > Scheme > Edit Scheme
3. 选择 Test 标签
4. 点击 + 添加 SenseFlowTests
5. 保存
```

---

### 问题：Mock 不工作

**症状：** 测试中注入 mock 但仍使用真实配置

**检查：**
```swift
// 确保使用协议类型
let config: WindowLayoutConfigurable = mockConfig  // ✅
let config = WindowLayoutConfig.default  // ❌ 硬编码

// 确保 manager 接受注入
let manager = FloatingWindowManager(layoutConfig: mockConfig)  // ✅
let manager = FloatingWindowManager.shared  // ❌ 使用单例
```

---

### 问题：测试很慢

**原因：** 使用真实 NSScreen 而不是 mock

**优化：**
```swift
// ❌ 慢：依赖真实屏幕
let screen = NSScreen.main!

// ✅ 快：使用 mock
let mockScreen = MockScreen(width: 1920, height: 1080)
```

---

## 📚 学习资源

### Apple 官方文档
- [Swift Testing](https://developer.apple.com/documentation/testing/)
- [Protocol-Oriented Programming](https://developer.apple.com/videos/play/wwdc2015/408/)
- [Environment Values](https://developer.apple.com/documentation/swiftui/environmentvalues)

### 推荐阅读
- Clean Architecture (Robert C. Martin)
- Test Driven Development (Kent Beck)
- Design Patterns (Gang of Four)

### 社区资源
- [Swift Forums - Testing](https://forums.swift.org/c/development/testing/)
- [Point-Free - Testing](https://www.pointfree.co/collections/testing)

---

## ✅ 检查清单

完成以下检查确保正确使用新架构：

- [ ] 理解协议和依赖注入的概念
- [ ] 能够运行现有测试
- [ ] 能够编写新的测试用例
- [ ] 知道如何使用 mock 隔离测试
- [ ] 了解如何在 SwiftUI 中使用环境值
- [ ] 配置了测试 scheme
- [ ] 查看了测试覆盖率报告
- [ ] 阅读了 SOLID_IMPROVEMENTS.md
- [ ] 阅读了 ARCHITECTURE_COMPARISON.md

---

**恭喜！你现在掌握了生产级的 Swift 测试和架构设计技能。** 🎉
