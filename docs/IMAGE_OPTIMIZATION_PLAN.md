# 图片加载优化方案

## 问题分析

### 当前实现（ClipboardItem.swift:106-117）

```swift
func getImage() -> NSImage? {
    if let imageData = imageData {
        return NSImage(data: imageData)  // ✅ 快速（内存）
    } else if let blobPath = blobPath {
        // ❌ 慢速（磁盘 I/O，同步阻塞主线程）
        let url = URL(fileURLWithPath: blobPath)
        if let data = try? Data(contentsOf: url) {
            return NSImage(data: data)
        }
    }
    return nil
}
```

### 性能问题

1. **同步磁盘 I/O**
   - `Data(contentsOf:)` 在主线程执行
   - 大图片（>512KB）读取时间：10-50ms
   - 多个卡片同时加载：累积延迟 50-200ms

2. **无缓存机制**
   - 每次打开窗口都重新加载图片
   - 重复的磁盘 I/O 操作

3. **渲染时加载**
   - 图片在视图渲染时才加载
   - 导致首次渲染卡顿

## 优化方案

### 方案 1：简单内存缓存（推荐）

**优点：**
- 实现简单，改动最小
- 立即生效，无需重构
- 适合当前场景（最多 200 个条目）

**缺点：**
- 内存占用较高（约 50-100MB）
- 应用重启后需重新加载

**实现：**

```swift
// 新增：ImageCache.swift
class ImageCache {
    static let shared = ImageCache()

    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.aiclipboard.imagecache")

    func getImage(for key: String) -> NSImage? {
        queue.sync { cache[key] }
    }

    func setImage(_ image: NSImage, for key: String) {
        queue.async { [weak self] in
            self?.cache[key] = image
        }
    }

    func clear() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
}
```

**修改 ClipboardItem：**

```swift
func getImage() -> NSImage? {
    let cacheKey = blobPath ?? uniqueId

    // 1. 检查缓存
    if let cached = ImageCache.shared.getImage(for: cacheKey) {
        return cached
    }

    // 2. 从内存加载（快速）
    if let imageData = imageData {
        let image = NSImage(data: imageData)
        if let image = image {
            ImageCache.shared.setImage(image, for: cacheKey)
        }
        return image
    }

    // 3. 从磁盘加载（慢速，但只加载一次）
    if let blobPath = blobPath {
        let url = URL(fileURLWithPath: blobPath)
        if let data = try? Data(contentsOf: url),
           let image = NSImage(data: data) {
            ImageCache.shared.setImage(image, for: cacheKey)
            return image
        }
    }

    return nil
}
```

**优点：**
- 只需修改一个方法
- 第二次打开窗口时图片已在缓存中
- 无需修改视图代码

**缺点：**
- 首次打开仍然是同步加载（但只慢一次）

---

### 方案 2：异步加载 + 内存缓存（最佳）

**优点：**
- 完全不阻塞主线程
- 首次打开也流畅
- 用户体验最佳

**缺点：**
- 需要修改视图代码
- 实现复杂度较高

**实现：**

```swift
// 修改 ClipboardCardView.swift
struct ClipboardCardView: View {
    let item: ClipboardItem
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var loadedImage: NSImage? = nil  // 新增

    var body: some View {
        // ... 其他代码
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text:
            // ... 文本预览

        case .image:
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: Constants.Card.imageMaxHeight)
                    .cornerRadius(Constants.cornerRadiusSmall)
            } else {
                // 加载中占位符
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: Constants.Card.imageMaxHeight)
                    .task {
                        // 异步加载图片
                        loadedImage = await loadImageAsync()
                    }
            }
        }
    }

    private func loadImageAsync() async -> NSImage? {
        let cacheKey = item.blobPath ?? item.uniqueId

        // 1. 检查缓存
        if let cached = ImageCache.shared.getImage(for: cacheKey) {
            return cached
        }

        // 2. 后台线程加载
        return await Task.detached(priority: .userInitiated) {
            if let imageData = item.imageData {
                let image = NSImage(data: imageData)
                if let image = image {
                    ImageCache.shared.setImage(image, for: cacheKey)
                }
                return image
            }

            if let blobPath = item.blobPath {
                let url = URL(fileURLWithPath: blobPath)
                if let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data) {
                    ImageCache.shared.setImage(image, for: cacheKey)
                    return image
                }
            }

            return nil
        }.value
    }
}
```

**优点：**
- 完全异步，不阻塞主线程
- 有加载状态反馈（ProgressView）
- 缓存机制确保后续快速显示

**缺点：**
- 首次打开会看到加载动画（但不卡顿）

---

### 方案 3：预加载 + 异步 + 缓存（终极方案）

**优点：**
- 窗口打开前就加载好图片
- 用户完全感觉不到延迟
- 最佳用户体验

**缺点：**
- 实现最复杂
- 需要修改多个文件

**实现：**

```swift
// 修改 ClipboardListViewModel.swift
class ClipboardListViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []

    func loadItems() async {
        let items = await repository.fetchRecent(limit: defaultItemLimit)

        // 预加载前 10 个图片（可见区域）
        await preloadImages(for: Array(items.prefix(10)))

        await MainActor.run {
            self.items = items
        }
    }

    private func preloadImages(for items: [ClipboardItem]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items where item.type == .image {
                group.addTask {
                    _ = await self.loadImageAsync(for: item)
                }
            }
        }
    }

    private func loadImageAsync(for item: ClipboardItem) async -> NSImage? {
        let cacheKey = item.blobPath ?? item.uniqueId

        if let cached = ImageCache.shared.getImage(for: cacheKey) {
            return cached
        }

        return await Task.detached(priority: .userInitiated) {
            // ... 加载逻辑（同方案 2）
        }.value
    }
}
```

**优点：**
- 窗口显示时图片已在缓存中
- 完全无感知的加载体验
- 只预加载可见区域（前 10 个）

---

## 推荐实施顺序

### 阶段 1：快速修复（方案 1）
- **时间**: 10 分钟
- **效果**: 第二次打开窗口时流畅
- **风险**: 低

### 阶段 2：完整优化（方案 2）
- **时间**: 30 分钟
- **效果**: 首次打开也流畅
- **风险**: 中（需要测试视图更新）

### 阶段 3：极致体验（方案 3）
- **时间**: 1 小时
- **效果**: 完全无感知
- **风险**: 中（需要协调数据加载和图片预加载）

## 性能预期

### 当前性能
- 首次打开：10 个图片 × 20ms = 200ms 延迟
- 第二次打开：200ms 延迟（无缓存）

### 方案 1 性能
- 首次打开：200ms 延迟
- 第二次打开：0ms 延迟（缓存命中）

### 方案 2 性能
- 首次打开：0ms 阻塞，200ms 异步加载（不影响动画）
- 第二次打开：0ms 延迟（缓存命中）

### 方案 3 性能
- 首次打开：0ms 延迟（预加载完成）
- 第二次打开：0ms 延迟（缓存命中）

## 内存占用估算

- 单张图片：约 500KB（解码后）
- 200 个条目，假设 50% 是图片：100 张
- 总内存：100 × 500KB = 50MB

**结论**: 内存占用可接受（macOS 应用通常 100-500MB）

## 下一步

1. **先用 Instruments 验证问题**
   - 确认图片加载确实是瓶颈
   - 测量实际加载时间

2. **实施方案 1（快速修复）**
   - 创建 ImageCache.swift
   - 修改 ClipboardItem.getImage()
   - 测试效果

3. **根据效果决定是否继续**
   - 如果方案 1 已经足够流畅，停止
   - 如果仍有问题，实施方案 2 或 3
