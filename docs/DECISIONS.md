# 架构决策记录 (ADR)

本文档记录项目中的关键技术决策。

**格式**: 每条决策包含：决策内容 + 理由 + 日期

---

## 2026-01-20

### 1. 采用 "文件外置上下文" 工作模式

**决策**: 项目规则、spec、决策、任务分离到独立文件，禁止在聊天中长篇复述

**理由**:
- 减少 token 消耗（避免重复复制长内容）
- 提高可维护性（文件比聊天记录更持久）
- 支持 compact 和会话切换（关键信息可恢复）

**相关文件**:
- `CLAUDE.md` - 项目规则入口
- `docs/SPEC.md` - 唯一真源 spec
- `docs/DECISIONS.md` - 本文件
- `docs/TODO.md` - 任务清单

---

### 2. Git 小步提交策略

**决策**: 每个提交只做一个主题，使用 `type(scope): summary` 格式

**理由**:
- 清晰的提交历史（易于回溯和审查）
- 便于 code review（每个提交职责单一）
- 支持 git bisect（快速定位问题引入的提交）

**提交格式**:
```
feat(ui): add clipboard history list
fix(db): resolve OCR text search query
docs(spec): update UI规范 to v0.2.1
```

---

### 3. 唯一真源 spec (Single Source of Truth)

**决策**: 只保留 `docs/SPEC.md` 作为唯一 spec，其他 spec 文件归档到 `spec/archive/`

**理由**:
- 避免规范冲突（多个 spec 版本不一致）
- 降低维护成本（只需更新一个文件）
- 减少 token 消耗（AI 只需读取一个 spec）

**迁移计划**:
- `spec/PRD_v0.1.md` → `spec/archive/`
- `spec/TECHNICAL_REFERENCE.md` → 保留（技术细节参考）

---

### 4. openspec / context7 使用限制

**决策**:
- openspec 只允许输出 patch/diff，禁止在对话里重写整篇 spec
- context7 只取 3 条最相关引用，每条最多 10 行

**理由**:
- 防止 token 雪球（长引用累积在对话中）
- 强制将引用结果写入 `docs/refs.md`（持久化）
- 提高响应速度（减少不必要的长输出）

---

### 5. 技术栈选择

#### MacPaw OpenAI Swift SDK (2026-01-20)

**决策**: 使用 MacPaw/OpenAI SDK 替代自实现的 URLSession API 调用

**理由**:
- 开箱即用的类型安全 API（ChatQuery, Message, Model 等）
- 支持 OpenAI 兼容格式的所有服务商（Claude/DeepSeek/Gemini 等）
- 自动处理错误和重试逻辑
- 活跃维护（最新版本 0.4.7，2025 年持续更新）
- 减少样板代码（~80 行 → ~40 行）

**参考**:
- [MacPaw/OpenAI GitHub](https://github.com/MacPaw/OpenAI)
- `docs/refs.md` - Context7 查询记录

---

#### SQLite.swift vs Core Data

**决策**: 使用 SQLite.swift

**理由**:
- 更轻量（比 Core Data 更快）
- 支持原生 SQL 查询和全文检索
- 类型安全的 Swift API
- 更好的性能（数据库查询 \u003c 50ms）

**参考**: [Maccy](https://github.com/p0deje/Maccy) 也使用 SQLite

---

#### SwiftUI + AppKit 混合架构

**决策**: UI 内容用 SwiftUI，窗口管理用 AppKit NSPanel

**理由**:
- SwiftUI 无法创建 NSPanel 和设置窗口层级
- AppKit 提供更精细的窗口控制（层级、圆角、毛玻璃）
- 内容层用 SwiftUI 提高开发效率

**实现**:
- `FloatingWindowManager.swift` - NSPanel 创建和配置
- `ClipboardListView.swift` - SwiftUI 内容视图
- `NSHostingController` - 桥接 SwiftUI 到 AppKit

---

#### Vision OCR vs 第三方库

**决策**: 使用 Apple Vision Framework

**理由**:
- 系统原生支持（无需额外依赖）
- 支持中文简繁体 + 英文
- macOS 12+ 兼容（VNRecognizeTextRequest）
- 免费且性能良好

**实现**: 后台异步执行（Task.detached），不阻塞主线程

---

### 6. Context7 前期调研规则

**决策**: 实现新功能前，必须先通过 Context7 查询最新 API 文档

**理由**:
- 避免使用已弃用的 API（减少技术债务）
- 使用最新最推荐的实现方式（最佳性能）
- 系统一致性（遵循 Apple 最新设计规范）

**示例**:
- 实现 Liquid Glass → 先查 "macOS NSVisualEffectView latest API 2026"
- 实现 OCR → 先查 "Vision framework text recognition API 2026"

---

### 7. Liquid Glass 视觉效果

**决策**: macOS 26 使用 `.glassEffect(.regular)`，不提供降级方案

**理由**:
- macOS 26 新设计语言（系统级应用标准）
- 简化代码，移除版本兼容性判断
- 专注最新系统体验

**实现**:
```swift
Color.clear
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
```

---

### 8. 设置面板 NavigationSplitView 布局

**决策**: v0.5 从 TabView 迁移为 NavigationSplitView（侧边栏 + 详情）

**理由**:
- 遵循 Apple "Adopting Liquid Glass" 官方指南
- 侧边栏在 Liquid Glass 层，内容层清晰分离
- macOS 标准设置面板模式（侧边栏导航）
- 灵活的列宽（150-400pt，理想 200pt）
- 更好的模块化和扩展性（易于新增设置分类）

**实现细节**:
- 窗口宽度从 600pt 增加到 650pt（200pt 侧边栏 + 450pt 内容）
- 使用 `SettingsSection` 枚举实现类型安全导航
- 应用 `.navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 400)`
- 所有内容视图保持不变（已使用 Form 布局，自动适配）

---

### 9. Keychain 批量读取优化

**决策**: v0.4 实现 Keychain 批量读取，减少授权提示从 3 次到 1 次

**理由**:
- 与 Phase 3 批量保存保持一致（读写都是批量操作）
- 改善开发者体验（Debug 构建时减少授权弹窗）
- 性能优化（单次调用获取所有密钥）

**实现**:
```swift
// KeychainManager 新增批量读取方法
func getAllSettingsKeys(for serviceType: AIServiceType) -> SettingsKeys {
    let apiKey = getAPIKey(for: serviceType)
    let publicKey = getLangfusePublicKey()
    let secretKey = getLangfuseSecretKey()
    return SettingsKeys(apiKey: apiKey, langfusePublicKey: publicKey, langfuseSecretKey: secretKey)
}

// PromptToolsSettingsView 使用批量读取
.onAppear {
    loadAllKeys()  // 单次批量读取，替代 3 次独立读取
}
```

**相关**:
- Phase 3: Keychain 批量保存（`fix-settings-ui-and-smart-ai-tool/specs/keychain-batch-save`）
- OpenSpec 提案: `batch-keychain-reads-on-settings-load`

---

### 10. Keychain 单密钥加密策略 (Deck 模式)

**决策**: v0.4.1 重构 KeychainManager，采用 Deck 的单密钥策略

**架构变更**:
- **Keychain**: 只存储 1 个 AES-256 主加密密钥 → 只需授权 1 次
- **UserDefaults**: 存储加密后的 API Keys → 无需授权，快速访问
- **内存缓存**: 缓存主密钥和解密后的 keys → 减少重复操作

**理由**:
1. **减少授权提示**: Keychain 访问从 7 次减少到 1 次（只读取主密钥）
2. **Debug 友好**: 即使重新签名，也只需授权 1 次（vs 之前每次 3 次）
3. **性能优化**: UserDefaults 访问比 Keychain 快 10-100 倍
4. **安全性**: 数据仍然加密存储（AES-256-GCM），主密钥受 Keychain 保护

**对比其他方案**:
- **Easydict**: UserDefaults 明文存储 → 安全性低
- **旧方案**: 每个 key 独立存 Keychain → 授权提示多
- **Deck 方案**: 单密钥 + 加密存储 → 平衡安全性和用户体验

**实现细节**:
```swift
// 主密钥管理
private func getMasterKey() -> SymmetricKey? {
    // 1. 检查内存缓存
    // 2. 从 Keychain 读取（只触发 1 次授权）
    // 3. 生成新密钥并保存
}

// 加密存储
func save(key: String, for account: String) -> Bool {
    let encrypted = encrypt(key)  // 使用主密钥加密
    UserDefaults.standard.set(encrypted, forKey: "encrypted_\(account)")
}
```

**数据迁移**:
- 首次启动自动检测旧的 Keychain 存储
- 迁移到新的加密存储
- 删除旧的 Keychain 条目

**标识符迁移** (v0.5):
- v0.5 更新所有标识符从 `com.aiclipboard.*` 到 `com.senseflow.*`
- 主密钥 service: `com.aiclipboard.masterkey` → `com.senseflow.masterkey`
- 队列标签: `com.aiclipboard.keychain.*` → `com.senseflow.keychain.*`
- 自动迁移机制：检测旧主密钥 → 复制到新位置 → 删除旧条目
- 迁移标志升级到 v2，确保所有用户运行新迁移

**参考**:
- Deck 项目: `SecurityService.swift:87-170`
- 调研记录: 2026-01-29 Easydict/Deck Keychain 实现对比

**日期**: 2026-01-29 (初始), 2026-02-26 (标识符迁移)

---

### 11. Langfuse 默认密钥策略

**决策**: Langfuse 密钥存储在 UserDefaults，应用启动时自动设置默认值

**理由**:
- **开箱即用**: 用户无需配置 Langfuse，直接可用
- **避免授权**: 不使用 Keychain，不触发授权提示
- **可配置**: 开发者选项可查看和修改密钥

**实现**:
```swift
// AppDelegate.swift
func initializeDefaultLangfuseKeys() {
    if UserDefaults.standard.string(forKey: "langfusePublicKey") == nil {
        UserDefaults.standard.set("pk-lf-...", forKey: "langfusePublicKey")
        UserDefaults.standard.set("sk-lf-...", forKey: "langfuseSecretKey")
    }
}
```

**读取顺序**:
1. 环境变量 `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY`
2. UserDefaults `langfusePublicKey` / `langfuseSecretKey`
3. 空字符串（禁用 Langfuse）

**对比**:
- **旧方案**: Keychain 存储 → 需要授权 → 用户体验差
- **新方案**: UserDefaults 存储 → 无需授权 → 开箱即用

**日期**: 2026-01-29

---

## 未来决策

（待补充新的架构决策）

---

**维护**: 每次重大技术决策都应追加到本文件，保持 3-5 条/次的简洁记录
