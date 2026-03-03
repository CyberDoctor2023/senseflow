# Swift Best Practices

Swift 编码最佳实践指南。

## 不可变性优先

```swift
// ✅ 推荐
let maxItems = 200
let windowHeight: CGFloat = 300

// ❌ 避免
var maxItems = 200  // 如果不会改变，用 let
```

## 可选值处理

```swift
// ✅ 推荐 - guard let 提前返回
guard let item = clipboardItems.first else { return }
processItem(item)

// ✅ 推荐 - if let 局部作用域
if let ocrText = item.ocrText {
    searchResults.append(ocrText)
}

// ❌ 避免强制解包
let text = item.text!  // 可能崩溃
```

## 异步处理

```swift
// ✅ 推荐 - async/await
func performOCR(image: NSImage) async throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // ...
    return recognizedText
}

// 调用
Task {
    let text = try await performOCR(image: clipboardImage)
}
```

## 资源管理

```swift
// ✅ 推荐 - weak self 避免循环引用
Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
    self?.checkClipboard()
}

// ✅ 推荐 - defer 确保清理
func processLargeFile() {
    let handle = openFile()
    defer { handle.close() }
    // ... 处理文件
}
```

## 错误处理

```swift
// ✅ 推荐 - 具体错误类型
enum DatabaseError: Error {
    case connectionFailed
    case queryTimeout
    case duplicateEntry
}

throw DatabaseError.duplicateEntry
```

## 文档注释

```swift
/// 从剪贴板历史中搜索匹配的条目
/// - Parameter query: 搜索关键词
/// - Returns: 匹配的剪贴板条目数组
func search(query: String) -> [ClipboardItem] {
    // ...
}
```
