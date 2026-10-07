# Database & Performance

SenseFlow 项目的数据库设计和性能优化指南。

## 数据库设计

### 表结构: clipboard_history

```sql
CREATE TABLE clipboard_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_id TEXT UNIQUE,           -- SHA256 hash
    type TEXT,                        -- 'text' | 'image'
    text_content TEXT,
    image_data BLOB,                  -- < 512KB
    blob_path TEXT,                   -- > 512KB
    timestamp INTEGER,                -- Unix timestamp
    app_name TEXT,
    app_path TEXT,
    ocr_text TEXT
);

CREATE INDEX idx_timestamp ON clipboard_history(timestamp);
CREATE INDEX idx_unique_id ON clipboard_history(unique_id);
```

### 去重机制

```swift
import CryptoKit

func generateHash(for content: String) -> String {
    let data = Data(content.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}

// 插入前检查
let hash = generateHash(for: clipboardText)
let exists = try db.scalar(items.filter(uniqueId == hash).count) > 0
if !exists {
    try db.run(items.insert(uniqueId <- hash, textContent <- clipboardText))
}
```

## 性能指标

| 指标 | 目标值 | 检查方法 |
|------|--------|----------|
| CPU 占用 | < 0.1% | `top -pid $(pgrep SenseFlow)` |
| 数据库查询 | < 50ms | SQLite EXPLAIN QUERY PLAN |
| 搜索响应 | < 10ms | 实时过滤测试 |
| 动画帧率 | 60fps | Instruments Time Profiler |

## 性能优化技巧

### 1. 数据库查询优化

```swift
// ✅ 使用索引
let recent = try db.prepare(items.order(timestamp.desc).limit(200))

// ✅ 限制结果数量
let searchResults = try db.prepare(
    items.filter(textContent.like("%\(query)%") || ocrText.like("%\(query)%"))
         .limit(50)
)

// ❌ 避免全表扫描
let all = try db.prepare(items)  // 不要这样做
```

### 2. 大文件分离存储

```swift
let maxInlineSize = 512 * 1024  // 512KB

if imageData.count > maxInlineSize {
    // 保存到文件系统
    let blobPath = saveToDisk(imageData, hash: uniqueId)
    try db.run(items.insert(blobPath <- blobPath))
} else {
    // 直接存入数据库
    try db.run(items.insert(imageData <- imageData))
}
```

### 3. 异步后台处理

```swift
// ✅ OCR 后台执行
Task.detached(priority: .utility) {
    let ocrText = try await performOCR(on: image)
    await MainActor.run {
        try? db.run(items.filter(id == itemId).update(ocrText <- ocrText))
    }
}
```

### 4. 历史记录清理（FIFO）

```swift
let maxItems = 200

func cleanupOldItems() throws {
    let count = try db.scalar(items.count)
    if count > maxItems {
        let deleteCount = count - maxItems
        let oldItems = try db.prepare(
            items.order(timestamp.asc).limit(deleteCount)
        )

        for item in oldItems {
            // 删除关联 blob 文件
            if let blobPath = item[blobPath] {
                try? FileManager.default.removeItem(atPath: blobPath)
            }
            try db.run(items.filter(id == item[id]).delete())
        }
    }
}
```

## 剪贴板监听优化

```swift
// ✅ 0.75 秒轮询间隔（平衡响应速度和 CPU 占用）
Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
    self?.checkClipboard()
}

// ✅ 暂停机制（避免自己捕获）
func writeToClipboard(_ content: String) {
    pauseMonitoring = true
    NSPasteboard.general.setString(content, forType: .string)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        pauseMonitoring = false
    }
}
```

## 性能测试

### CPU 占用测试

```bash
# 后台运行应用，监控 5 分钟
top -pid $(pgrep SenseFlow) -stats cpu -l 300 -s 1
```

### 数据库查询性能测试

```bash
# 测试查询时间
time sqlite3 clipboard.sqlite "SELECT * FROM clipboard_history WHERE text_content LIKE '%test%' LIMIT 50;"
```

### 内存使用测试

```bash
# 添加 200+ 条记录后检查内存
leaks SenseFlow
```
