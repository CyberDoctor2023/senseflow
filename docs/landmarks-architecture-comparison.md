# Landmarks vs SenseFlow 设置架构对比分析

> 对比基准：Apple Landmarks (Liquid Glass) 示例项目
> 更新日期：2026-02-10

---

## 1. 入口文件对比

### Landmarks: `LandmarksApp.swift`

```swift
@main
struct LandmarksApp: App {
    @State private var modelData = ModelData()     // App 层创建 Model

    var body: some Scene {
        WindowGroup {
            LandmarksSplitView()
                .environment(modelData)             // 新 Environment API 注入
                .frame(minWidth: 375.0, minHeight: 375.0)  // 只设最小值
        }
    }
}
```

**关键特征：**
- `WindowGroup` 场景 → 系统自动管理三个窗口按钮（关闭/最小化/全屏）
- `@State` 创建 Model（非 `@StateObject`）
- `.environment(modelData)` 注入（新 API，非 `.environmentObject()`）
- `.frame(minWidth:, minHeight:)` 只限制最小值，窗口可自由缩放

### SenseFlow: `SenseFlowApp.swift`（修改后）

```swift
@main
struct SenseFlowApp: App {
    @State private var settingsModel = SettingsModel()  // ✅ App 层创建

    var body: some Scene {
        Window("设置", id: "settings") {
            SettingsView()
                .environment(settingsModel)              // ✅ 新 API 注入
                .environmentObject(dependencies)
                .frame(minWidth: ..., minHeight: ...)     // ✅ 只设最小值
        }
    }
}
```

### 差异说明

| 项目 | Landmarks | SenseFlow | 原因 |
|------|-----------|-------------|------|
| Scene 类型 | `WindowGroup` | `Window(id:)` | 设置窗口应为单实例，`Window` 更合适 |
| 额外 DI | 无 | `.environmentObject(dependencies)` | 项目需要 DependencyEnvironment 注入协调器 |

### 为什么旧版只有关闭按钮？

旧版使用 `Settings { }` 场景。这是 Apple 专门为"偏好设置"设计的场景类型，它的 NSWindow 被配置为 **utility window**：
- `styleMask` 不包含 `.miniaturizable` 和 `.resizable`
- 系统故意隐藏最小化和全屏按钮
- 这是 Apple 的设计决策，不是 bug

改为 `Window(id:)` 后，创建的是标准 NSWindow，默认包含全部三个按钮。

---

## 2. 主视图架构对比

### Landmarks: `LandmarksSplitView.swift`

```swift
struct LandmarksSplitView: View {
    @Environment(ModelData.self) var modelData      // 从 Environment 接收
    @State private var preferredColumn: NavigationSplitViewColumn = .detail

    var body: some View {
        @Bindable var modelData = modelData         // body 内创建 Bindable

        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            List {
                Section {                            // Section 包裹
                    ForEach(NavigationOptions.mainPages) { page in
                        NavigationLink(value: page) {
                            Label(page.name, systemImage: page.symbolName)
                        }
                    }
                }
            }
            .frame(minWidth: 150)
        } detail: {
            NavigationStack(path: $modelData.path) {
                NavigationOptions.landmarks.viewForPage()
            }
        }
        .searchable(text: $modelData.searchString, prompt: "Search")
        .inspector(isPresented: $modelData.isLandmarkInspectorPresented) { ... }
    }
}
```

### SenseFlow: `SettingsView.swift`（修改后）

```swift
struct SettingsView: View {
    @Environment(SettingsModel.self) var model       // ✅ 对标 @Environment
    @State private var selectedSetting: SettingOption? = .general

    var body: some View {
        @Bindable var model = model                  // ✅ 对标 body 内 Bindable

        NavigationSplitView {
            List(selection: $selectedSetting) {
                Section {                             // ✅ 对标 Section 包裹
                    ForEach(SettingOption.allCases) { option in
                        NavigationLink(value: option) {
                            Label(option.title, systemImage: option.symbolName)
                        }
                    }
                }
            }
            .frame(minWidth: ...)
        } detail: {
            (selectedSetting ?? .general).viewForPage(model: model)  // ✅ viewForPage
        }
    }
}
```

### `@Bindable` 的作用

```swift
// 这行代码的意义：
@Bindable var model = model
```

`@Environment` 返回的是只读引用。要在子视图中双向绑定（`$model.xxx`），必须通过 `@Bindable` 包装。Landmarks 在 `body` 内部做这个转换，而不是在属性声明处，这是 Apple 推荐的模式。

### `Section { }` 的作用

```swift
List {
    Section {           // ← 这个 Section
        ForEach(...) { ... }
    }
}
```

`Section` 在 macOS 的 `List` 中提供：
- 视觉分组（带圆角背景）
- 与 Liquid Glass 风格的 sidebar 一致性
- 可选的 header/footer 标签
- 没有它，List 项目之间没有视觉分隔层次

---

## 3. 数据模型对比

### Landmarks: `ModelData.swift`

```swift
@Observable @MainActor
class ModelData {
    var landmarks: [Landmark] = []
    var searchString: String = ""
    var path: NavigationPath = NavigationPath()
    // ... 业务逻辑方法
}
```

### SenseFlow: `SettingsModel.swift`（修改后）

```swift
@Observable @MainActor                               // ✅ 双标注
class SettingsModel {
    private let defaults = UserDefaults.standard

    var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: ...) }  // UserDefaults 同步
    }
    // ...
}
```

### `@MainActor` 的作用

`@Observable` 的属性变更会触发 SwiftUI 视图更新。加上 `@MainActor` 确保：
- 所有属性读写都在主线程
- 避免并发访问导致的 UI 更新竞态
- 与 SwiftUI 的渲染管线一致

### 为什么 Landmarks 不用 `@AppStorage`？

Landmarks 的数据来自 JSON/API，不需要持久化到 UserDefaults。SenseFlow 的设置需要持久化，所以用 `didSet` 手动同步 UserDefaults —— 这是 `@Observable` + UserDefaults 的标准桥接方式。

---

## 4. 侧边栏选项对比

### Landmarks: `NavigationOptions.swift`（独立文件）

```swift
enum NavigationOptions: Equatable, Hashable, Identifiable {
    case landmarks, map, collections

    static let mainPages: [NavigationOptions] = [.landmarks, .map, .collections]

    var name: LocalizedStringResource { ... }
    var symbolName: String { ... }

    @MainActor @ViewBuilder func viewForPage() -> some View {
        switch self {
        case .landmarks: LandmarksView()
        case .map: MapView()
        case .collections: CollectionsView()
        }
    }
}
```

### SenseFlow: `SettingOption.swift`（独立文件，修改后）

```swift
enum SettingOption: String, Equatable, Hashable, Identifiable, CaseIterable {
    case general, shortcuts, smartAI, ...

    var title: String { ... }
    var symbolName: String { ... }                     // ✅ 对标 symbolName

    @MainActor @ViewBuilder func viewForPage(model: SettingsModel) -> some View {
        switch self {                                  // ✅ 对标 viewForPage
        case .general: GeneralSettingsView(model: model)
        // ...
        }
    }
}
```

### `viewForPage()` 的作用

将视图路由逻辑从主视图移到 enum 自身：
- **职责分离**：主视图只负责布局，enum 知道自己对应什么视图
- **可测试性**：enum 可以独立测试路由逻辑
- **一致性**：新增选项只需改 enum，不需要改主视图

### `Hashable` 的作用

`NavigationLink(value: option)` 要求 `value` 遵循 `Hashable`。`List(selection:)` 也需要 `Hashable` 来追踪选中状态。没有它编译不会报错（因为 `Identifiable` 有时够用），但加上才是完整正确的。

---

## 5. 子视图数据传递对比

### Landmarks 模式

```
App (@State modelData)
  └─ .environment(modelData)
       └─ SplitView (@Environment + @Bindable)
            └─ DetailView (@Environment or @Bindable)
```

### SenseFlow 模式（修改后）

```
App (@State settingsModel)
  └─ .environment(settingsModel)
       └─ SettingsView (@Environment + @Bindable)
            └─ viewForPage(model:)
                 └─ GeneralSettingsView(@Bindable var model)
                 └─ SmartAISettingsView(@Bindable var model)
                 └─ AdvancedSettingsView(@Bindable var model)
                 └─ PrivacySettingsView(@Bindable var model)
```

---

## 6. 旧版 vs 新版变更总结

| 旧版 | 新版 | 为什么变好了 |
|------|------|-------------|
| `Settings { }` scene | `Window(id:) { }` scene | 获得三个窗口按钮 |
| `@AppStorage` 分散在各视图 | `@Observable SettingsModel` 集中管理 | 数据与视图分离 |
| `.environmentObject()` | `.environment()` | 使用 Swift 5.9+ 新 API，类型安全 |
| `@State` 在 SettingsView | `@State` 在 App 层 | 模型生命周期与 App 一致 |
| enum 嵌套在视图内 | 独立 `SettingOption.swift` | 对标 NavigationOptions |
| `switch` 在主视图 | `viewForPage()` 在 enum | 路由职责归属 enum |
| `List { ForEach }` | `List { Section { ForEach } }` | Liquid Glass 视觉分组 |
| 无 `@MainActor` | `@Observable @MainActor` | 线程安全 |

---

## 7. 文件对应关系

| Landmarks | SenseFlow | 作用 |
|-----------|-------------|------|
| `LandmarksApp.swift` | `SenseFlowApp.swift` | App 入口 + Model 创建 + 注入 |
| `LandmarksSplitView.swift` | `SettingsView.swift` | NavigationSplitView 布局 |
| `ModelData.swift` | `SettingsModel.swift` | @Observable 数据模型 |
| `NavigationOptions.swift` | `SettingOption.swift` | 侧边栏 enum + viewForPage |
| `Constants.swift` | `Constants.swift` | 设计常量 |
