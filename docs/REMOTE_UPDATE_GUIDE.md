# 远程更新功能实现指南

## 概述

实现了从 prompts.chat 远程更新社区工具的完整功能，用户可以一键更新工具库。

---

## 架构设计

```
prompts.chat API
    ↓
ToolUpdateService（更新服务）
    ↓
DatabaseManager（数据库）
    ↓
PromptToolManager（工具管理）
    ↓
CommunityToolsBrowserView（UI）
```

---

## 已实现的文件

### 1. **ToolUpdateService.swift** - 更新服务
- `checkForUpdates()` - 检查可用更新
- `installTool()` - 安装单个工具
- `installTools()` - 批量安装工具
- `ToolFilter.isContentProcessing()` - 过滤适合剪贴板的工具

### 2. **PromptTool.swift** - 数据模型扩展
新增字段：
- `source: ToolSource` - 工具来源（builtin/community/custom）
- `remoteId: String?` - prompts.chat 的工具 ID
- `remoteAuthor: String?` - 作者名称
- `remoteVotes: Int` - 点赞数
- `remoteUpdatedAt: Date?` - 远程更新时间

新增属性：
- `isCommunityTool` - 是否为社区工具
- `isUpdatable` - 是否可更新

### 3. **DatabaseManager+PromptTools.swift** - 数据库扩展
- `migrateToV04()` - 数据库迁移到 v0.4
- `fetchCommunityTools()` - 获取所有社区工具
- `fetchToolByRemoteId()` - 根据远程 ID 查询
- `insertOrUpdatePromptTool()` - 插入或更新工具

### 4. **CommunityToolsBrowserView.swift** - UI 界面
- 社区工具浏览器
- 搜索功能
- 更新提示横幅
- 一键安装/更新

---

## 使用流程

### 用户视角

1. **打开社区工具浏览器**
   ```
   设置 → Prompt Tools → 浏览社区工具
   ```

2. **自动检查更新**
   - 启动时自动检查（24小时一次）
   - 发现更新时显示横幅提示

3. **安装工具**
   - 浏览工具列表
   - 点击"安装"按钮
   - 工具自动添加到本地数据库

4. **更新工具**
   - 点击"立即更新"
   - 批量更新所有社区工具

### 开发者视角

```swift
// 1. 检查更新
let service = ToolUpdateService.shared
let updateInfo = try await service.checkForUpdates()

if updateInfo.hasUpdates {
    print("发现 \(updateInfo.newTools.count) 个新工具")
    print("发现 \(updateInfo.updatedTools.count) 个更新")
}

// 2. 安装工具
let success = service.installTool(remoteTool)

// 3. 批量安装
let result = await service.installTools(remoteTools)
print("成功: \(result.success), 失败: \(result.failed)")
```

---

## 数据库迁移

### 自动迁移

在 `DatabaseManager.setupDatabase()` 中添加：

```swift
// 数据库迁移
try migrateIfNeeded()
try migrateToV04()  // 添加这行
```

### 手动迁移

```sql
-- 添加新字段
ALTER TABLE prompt_tools ADD COLUMN source TEXT DEFAULT 'custom';
ALTER TABLE prompt_tools ADD COLUMN remote_id TEXT;
ALTER TABLE prompt_tools ADD COLUMN remote_author TEXT;
ALTER TABLE prompt_tools ADD COLUMN remote_votes INTEGER DEFAULT 0;
ALTER TABLE prompt_tools ADD COLUMN remote_updated_at REAL;

-- 更新现有默认工具
UPDATE prompt_tools SET source = 'builtin' WHERE is_default = 1;

-- 更新版本号
PRAGMA user_version = 4;
```

---

## 工具过滤逻辑

### 关键词过滤

**保留的关键词**（内容处理）：
- translate, improve, correct, format
- rewrite, polish, summarize, extract
- convert, edit, proofread, simplify

**排除的关键词**（内容生成）：
- create, generate, write a, come up with
- design, develop, build, make

### 模式匹配

检查 prompt 是否包含：
- "I will provide..."
- "I will give..."
- "I will type..."

---

## 集成到设置界面

在 `PromptToolsSettingsView.swift` 中添加：

```swift
struct PromptToolsSettingsView: View {
    @State private var showingCommunityBrowser = false

    var body: some View {
        VStack {
            // 现有的工具列表
            toolsList

            // 添加社区工具按钮
            Button("浏览社区工具") {
                showingCommunityBrowser = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingCommunityBrowser) {
            CommunityToolsBrowserView()
                .frame(width: 800, height: 600)
        }
    }
}
```

---

## API 限制和注意事项

### prompts.chat API

- **免费使用**，但需要合理控制请求频率
- **无需 API Key**（公开 prompts）
- **速率限制**：未明确说明，建议每次请求间隔 > 1秒

### 缓存策略

- 24小时内不重复检查更新
- 使用 `UserDefaults` 存储上次检查时间
- 本地缓存已安装的工具

### 错误处理

```swift
enum ToolUpdateError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case databaseError
}
```

---

## 测试清单

- [ ] 数据库迁移成功
- [ ] 从 API 获取工具列表
- [ ] 过滤出适合剪贴板的工具
- [ ] 安装单个工具
- [ ] 批量安装工具
- [ ] 检查更新功能
- [ ] 更新现有工具
- [ ] UI 界面显示正常
- [ ] 搜索功能正常
- [ ] 错误处理和提示

---

## 下一步优化

### Phase 1（当前）
- ✅ 基础 API 集成
- ✅ 工具过滤
- ✅ 安装和更新
- ✅ UI 界面

### Phase 2（v0.5）
- [ ] 工具详情页（预览 prompt）
- [ ] 分类筛选
- [ ] 标签筛选
- [ ] 排序（按点赞数、时间）
- [ ] 收藏功能

### Phase 3（v1.0）
- [ ] 分享自定义工具到 prompts.chat
- [ ] 工具使用统计
- [ ] 推荐算法
- [ ] 离线模式优化

---

## 常见问题

### Q: 如何测试 API 连接？

```bash
curl "https://prompts.chat/api/prompts?type=TEXT&limit=5"
```

### Q: 如何查看数据库内容？

```bash
sqlite3 ~/Library/Application\ Support/SenseFlow/clipboard.sqlite
.schema prompt_tools
SELECT * FROM prompt_tools WHERE source = 'community';
```

### Q: 如何重置社区工具？

```swift
let communityTools = DatabaseManager.shared.fetchCommunityTools()
for tool in communityTools {
    DatabaseManager.shared.deletePromptTool(id: tool.id)
}
```

---

## 参考资料

- [prompts.chat API 文档](https://prompts.chat/docs/api)
- [prompts.chat GitHub](https://github.com/f/awesome-chatgpt-prompts)
- [SQLite.swift 文档](https://github.com/stephencelis/SQLite.swift)

---

**最后更新**: 2026-01-26
