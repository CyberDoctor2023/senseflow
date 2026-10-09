# SenseFlow：性能优先重构计划与代码审查

日期：2026-10-06。本报告主体记录实施前静态审查与计划。授权后的第一阶段实现、构建、AppKit/SQLite 验证和性能对照另见 `DOCUMENT_IMPLEMENTATION_VALIDATION_2026-10-06.md`；未验证的静态风险仍不视为实测瓶颈。

入口：`REFACTOR_SPEC_2026-10-06.md`。本次覆盖 133 个应用 Swift 文件的结构与关键调用链，重点深入历史面板、数据库、图片缓存、剪贴板监听、取词、Smart AI 上下文、工具入口和性能测试；不是逐行审计所有文件。

## P0：先解决真实闪退

新证据见 `CRASH_REVIEW_2026-10-06.md`：安装版 0.6.0 build 7 于今天 16:29 在后台 OCR 的 CheckedContinuation.resume 触发 SIGTRAP。本地 OCR 回调与 perform catch 都能 resume，存在重复恢复结构。先核验构建来源并修 OCR 生命周期/失败处理，验证后再推进以下性能阶段。异常退出反馈安排在下次启动，不能靠已崩溃进程弹窗。

## 结论与顺序

保留 SwiftUI + AppKit + SQLite 技术栈。先建立真实基线并移出主线程重工作，再简化刷新与状态；然后做原生界面、自适应原文预览和固定工具 workflow。最后清理无用模块/依赖与目录。embedding/RAG 是可选检索增强，独立后台建设，不作为卡顿修复前提。

仅删冗余文档不会直接改善运行时流畅度。当前产品代码约 1 MB，docs 约 1.8 MB，openspec 约 712 KB，out 约 40 MB（整理前目录大小）。性能优化必须对准执行路径，而不是源文件数量。

## 已证实的代码问题与静态风险

### P1：卡片 body 的同步图片加载

- 证据：`SenseFlow/Views/ClipboardCardView.swift:96` 调用 `ClipboardImageCache.shared.image(for:)`；`Services/ClipboardImageCache.swift:111–126` 缓存 miss 后执行 `Data(contentsOf:)` 并创建原图 `NSImage`。同一同步接口用于粘贴（`Views/ClipboardListView.swift:156–160`）。
- 结论：滚动/首屏渲染包含同步磁盘读取，缓存不能解决首次 miss；原图与预览未分层。卡顿程度尚未测量。
- 修复：后台生成按像素尺寸受限的缩略图，显示态持有加载结果；可见卡片优先、相邻有限预取、隐藏后取消无用任务。原图只在明确复制/预览操作载入，不能把缩略图写回剪贴板。
- 约束：以 content hash + 目标像素尺寸 + scale 作缓存键；同一资源合并并发请求；解码成本按像素计；处理文件缺失与图片方向。

### P1：主线程剪贴板轮询直接进入持久化

- 证据：`Services/ClipboardMonitor.swift:48–65` 在主 RunLoop 设置 timer；`handleImageData:296`、`handleTextContent:309` 直接调用 `DatabaseManager.insertItem`。后者 `Managers/DatabaseManager.swift:197–227` 同步执行 SHA256、查重、删除、写入、清理；大图可在 `processImageData:354` 写文件。
- 结论：读剪贴板后的重工作与 UI 共用主线程。轮询间隔本身不是已证明的根因。
- 修复：主线程只快照变更、来源与最少内容；后台有界队列处理 hash、持久化、缩略图及 OCR。完整数据库操作由单一 actor/串行所有者管理，不为每次查询创建无管理的 detached task。
- 约束：任务顺序、快速多次复制、应用来源快照、退出/取消、失败可重试；明确容量和溢出策略，不能静默丢历史。

### P1：重复加载、旧搜索回写、整批动画

- 证据：`ViewModels/ClipboardListViewModel.swift:34–65` 每个 debounce 结果独立发起 Task，没有 cancellation/generation 校验；`loadItems` 与 `performSearch` 均以动画替换整个数组。`Views/UnifiedPanelView.swift:67–84` 清空搜索并直接加载；`ClipboardListView.swift:115–124` 另有首次 task 与通知加载入口。
- 结论：存在冗余查询与旧请求覆盖新请求的可能；是否每次开窗重复查询取决于当时 query/生命周期，需计数确认。
- 修复：统一 refresh/search 所有权，最新请求令牌校验、取消/合并、removeDuplicates；显示上次有效摘要，不用空列表充当 loading；局部插入更新稳定 ID，不把每次数据回写都动画化。
- 约束：错误与“没有结果”区分，搜索期间的新捕获按当前 query 刷新，隐藏窗口不做无意义 UI reload。

### P1：查重采用删除重插，清理按秒级时间误删风险

- 证据：`DatabaseManager.swift:210–213` 查重后删旧记录，随后创建新 row；`deleteOldestRecords:578–594` 先按 limit 选旧记录，却用 `timestamp <= oldestTimestamp` 删除数据库记录。timestamp 在 `insertToDatabase:261` 是秒级整数。
- 结论：重复内容破坏稳定 ID/OCR 与缓存复用；多记录同秒时，清理范围可超过所选 ID 集合，并使数据库删除集合与 blob 清理集合不同。
- 修复：同一内容保留 ID，只更新 recency/必要来源元信息；查重更新在事务中执行。按选中记录 ID 精确删除，排序 timestamp + ID，commit 后管理 blob 生命周期。
- 约束：重复图不重跑已完成 OCR；数据库与文件跨介质失败必须可恢复，禁止先删 blob 再留下数据库悬空引用。

### P1：自触发剪贴板忽略标志消费时机错误

- 证据：`ClipboardMonitor.swift:97–125` 在检查 changeCount 之前就消费 `shouldIgnoreNextChange`，且未同步 lastChangeCount。
- 结论：一次忽略的 tick 后，下一 tick 仍可检测到自己写入；也可能忽略之后发生的用户复制。不是注释宣称的“精确忽略变化”。
- 修复：由统一剪贴板写入器记录成功写入的 changeCount，捕获器比较实际写入版本，不能用“忽略一个 timer tick”代替“忽略自己写入”。
- 约束：测试成功/失败写入、timer 在写入前后触发、连续真实用户复制、工具输出和自动粘贴路径。

### P1：迁移阶梯使用固定初始版本

- 证据：`Infrastructure/Database/DatabaseMigrationManager.swift:114–126` 将同一 `currentVersion` 传给所有迁移函数，各函数 `:140–175` 只在相等版本执行；v1 升到 v2 后，本轮 v2→v3 guard 仍看到 1。
- 结论：阶梯迁移没有按每步更新版本向前推进；prompt 字段前置修补是否掩盖部分问题需用旧 schema fixture 确认。
- 修复：单一 schema owner 顺序迁移，读取更新版本或明确 version range；每步事务化；删除重复迁移定义前核验调用与工程 membership。
- 约束：v0/v1/v2/v3/v4/v5 全部直接升级到目标 schema，失败保留备份与原数据；本轮不触碰真实用户数据库。

### P2：取词阻塞与 Smart AI 屏幕覆盖层

- 证据：`Services/TextSelectionMonitor.swift:58–105` 在主队列处理全局 mouseUp，强制取词调用 `Services/TextExtractor.swift:74–100` 的同步重试 `usleep(10_000)`。
- Smart 路径：`Adapters/Services/SystemContextCollector.swift:49–56` 非轻量模式采截图；`SystemContextScreenshotCollector.swift:143–197` 依次取全屏与焦点截图、遍历 UI 树并展示 overlay，`:277–303` 在 MainActor render/encode。`OpenClawUITreeLiveOverlayPresenter.swift:25–53,70–110` 生成屏幕大小位图；`OpenClawUITreeOverlayRenderer.swift:138` 显示 ref/role/name。
- 结论：AX 用户可见来源很可能在这条覆盖层，但未在运行界面确认“AX 数”具体位置，不能声称已完全定位。该路径是 Smart 请求触发，不是已证明的常驻滚动瓶颈。
- 修复：固定工具用显式选中文本/历史记录/剪贴板作为输入，不采整个桌面；生产界面删除 UI 树标注和 live overlay 入口，连同无消费者的依赖一起删。按需取词仍可用 Accessibility；不删除自动粘贴权限能力。强制 Cmd+C 改异步有限超时，默认不常驻捕获。

### P2：渲染成本及加载体积

- 证据：卡片每项 `.drawingGroup` (`ClipboardCardView.swift:64`) + 材质 + 阴影 + hover scale；列表已经用 LazyHStack。查询 (`DatabaseManager.swift:381–450`) 返回包含 image_data 的完整记录，每次最多 200 条；ViewModel limit 不读取历史设置。
- 结论：离屏合成及整批 BLOB 是可优化候选，不能断言 drawingGroup 必然更慢或 NSCache 是严格 LRU/硬内存上限。
- 修复：列表摘要不带 BLOB/完整长文，按需详情；首屏有限分页。玻璃留给窗口/主要控件，卡片轻量背景；对 drawingGroup 有/无、阴影/动画做同设备 A/B profile。

### P2：测试与文档无法证明当前性能

- `SenseFlowTests/PerformanceTests/PerformanceTests.swift` 主要 measure Mock 工具与协调器；名为 memory usage 的测试实际测 wallClockTime。没有覆盖真实图片冷缓存、滚动、SQL/主线程或 UI 首屏。
- `docs/SPEC.md` 宣称 CPU <0.1%、60fps 全已通过，却无本轮环境/trace；TODO 与 ADR 对设置导航、最低系统和视觉降级互相矛盾。
- `project.pbxproj` 同时存在部署目标 14.0、14.6、15.6，Swift 5/6 配置；精确生效 target/settings 应在正式验证时确认，不依据项目 AGENTS 的 26.0 宣称删兼容。
- 未调用的同步 `NotificationService.hasPermission:90–101` 含无期限 semaphore.wait；目前搜索不到调用者，归为死代码候选，不能称其已导致卡顿。

## 目标结构：减少所有者，而不是再堆一套架构

```text
App composition
  ├─ ClipboardCapture → HistoryStore → HistoryQuery
  │                      ├─ BlobStore
  │                      ├─ bounded Thumbnail jobs
  │                      └─ bounded OCR jobs
  ├─ HistoryPresentation → native HistoryPanel + DetailPreview
  └─ ToolRegistry → ToolRunner → LocalTransform / AITransport
                              → ResultPreview → ClipboardWriter / AutoPaste
```

- 一套 HistoryStore 负责读写/迁移/事务，一套 presentation 状态负责查询/选中/预览；不让 Views 直接绕到 DatabaseManager/共享捕获器。
- `ClipboardRepository` 与 `ClipboardRepositoryProtocol` 两份合同合并到一个有实际消费者的接口，查询/详情/写入清晰分开；删除未使用合同，避免保留空壳。
- 保留已有 SQLite 与工具配置，逐段替换实际入口后删除旧 manager 路径；迁移是一次性 schema/data 迁移，不是平行 UI 或 shadow states。
- 全局快捷键统一所有权；Carbon 与 KeyboardShortcuts 谁负责实际注册需审计调用者，不能仅因两者同时存在就删除依赖。

## 原生界面与自适应预览（主线已更新）

用户明确长文本为重构重点：鼠标划过长文卡片后，弹出类似 Word 的原生文档窗口，完整阅读并支持编辑。完整产品合同见 `prd/LONG_TEXT_DOCUMENT_PREVIEW.md`；解耦/状态/存储/焦点/性能设计见 `design/LONG_TEXT_DOCUMENT_PREVIEW.md`。它们覆盖本计划旧选中详情方案。

悬停约 350 ms 后展示、不抢焦点；跨入预览保持窗口，点击正文进入固定编辑会话，其他 hover 不替换文稿。采用 SwiftUI chrome + AppKit NSTextView/NSScrollView，纯文本首版支持撤销、查找与中文输入。窗口按有限排版自适应，超出屏幕高度后滚动，禁止先全文排版再显示。

原始捕获不改，编辑自动 checkpoint 草稿；显式保存新记录，复制独立触发。应用异常退出后可恢复已持久化草稿，当前会话可能丢失最后 checkpoint 后输入，不承诺零丢失。窗口焦点必须从现有 A/B 身份判断迁至工作区归属，避免点编辑导致历史误关闭。

核心交付顺序：P0 闪退修复 → 长文本阅读/编辑的必要 store 与主线程治理 → hover 文档窗口 → 编辑/草稿/恢复 → 性能实测。工具/RAG/目录清理后置，不能占用主线先交付预算。

## 工具与检索

第一批工具：中英翻译、润色、摘要；本地去空白/统一换行、JSON 格式化与校验。保留自定义 prompt、快捷键和已有工具数据。模型调用和确定性格式化分开，简单处理不付出网络延迟。

ToolRunner 显式接收输入快照，支持 selected history item，不能用户选了历史 A 却读取当前剪贴板 B。输出先可预览，再由复制/替换动作处理；取消与失败不覆盖原剪贴板。固定 workflow 使用 tool ID、输入类型、步骤、输出策略的轻量合同，暂不做自由 Agent 调度。

embedding/RAG：先确认关键词搜索对哪些真实任务不足。若需语义检索，独立规格确定本地/远程模型、隐私、成本、离线表现、chunking、版本/hash 去重与重建机制。增量索引可暂停、有界后台运行；查询失败仍保留独立关键词搜索。RAG 只按明确动作读选中的相关历史，不自动发送全部历史或截图。当前代码搜索未发现实际 embedding/RAG 索引链路，不能把宣传定位当作已实现功能。

## 分阶段实施与验收

### 阶段 0：建立可重复基线（第一步）

确认项目 Git 来源、签名、scheme、真实部署 target；首次正式验证前通过官方 Xcode MCP 发现 live workspace。保存当前历史与配置迁移用的脱敏 fixture。用同一台机器、Release 配置、相同数据、相同操作脚本采样 cold/warm 首屏、搜索、连续复制、滚动、长文预览与 idle。

记录硬件/系统/Xcode、build configuration、数据量、cold/warm、30 次样本、p50/p95、CPU、RSS、UI hitches、主线程堆栈；用 SwiftUI Instrument + Time Profiler + Hangs/Allocations 分辨查询/排版/磁盘/合成成本。禁止用 Mock AI 时间作整机流畅度指标。

### 阶段 1：主线程与数据正确性（P1）

实施单一 store 所有权、捕获快照/后台写入、稳定 ID 查重、精确清理、迁移阶梯、self-write changeCount。新增建议 focused tests：`testDuplicateCapturePreservesIDAndOCR`、`testPruningDeletesExactIDsWithEqualTimestamps`、`testCaptureIgnoresOnlyOwnWrittenVersion`、`testEveryLegacySchemaMigratesToTarget`。这些是待新增测试名称，尚未存在或运行。

验收：对应 focused tests + 最小 build 通过；真实连续复制时主线程不再出现 hash/blob write/SQL 业务操作；历史、原图、OCR、工具配置迁移前后数量和 hash 可核对。

### 阶段 2：轻量列表、缩略图、任务与刷新（P1）

实施摘要查询、按需详情、有限分页、后台缩略图、有界 OCR、latest-query 校验、合并刷新及稳定 diff；移除无证据离屏优化，按 A/B 数据确定视觉成本。测试建议：`testListSummariesExcludeImagePayloads`、`testStaleSearchCannotReplaceLatestQuery`、`testConcurrentThumbnailRequestsCoalesce`、`testCopyImageUsesOriginalData`。

验收：一轮 query/state 只产生一轮有效刷新；冷缓存滚动无同步文件读栈；大图复制保留原件；后台队列可取消且峰值有界。

### 阶段 3：核心长文本文档窗口与编辑（P1，产品主线）

按长文本 PRD/设计的五个切片实施：无色条历史 + hover 全文窗口 + 阅读到编辑 + 草稿/保存/恢复 + 性能验证。窗口、native editor、store、hover coordinator 解耦；原文保持不变，显式保存新版本。原生 IME/Undo/Find、pointer corridor、内部焦点、多屏、100k/1M 全文、故障注入与草稿恢复均须验收，详见 LT-01 至 LT-10。不能只交一个只读 popover 就标完成。

### 阶段 4：固定工具 workflow（P2）

统一工具执行入口与快捷键、显式输入与结果预览，添加上述本地/AI 工具，收拢 provider transport。AI API/模型选择以实施当日官方文档核验，不在本计划盲目升级所有 SDK。测试建议：`testToolUsesSelectedItemSnapshot`、`testCancelledToolDoesNotOverwriteClipboard`、`testLocalJSONFormattingDoesNotCallAI`。

### 阶段 5：目录与依赖清理（P2）

先产出引用图：源文件 → target membership → 实际消费者 → 依赖 product。以下是候选，不是已证实安全删除清单：

- 根目录一次性 add/fix/rename/rebuild Ruby 脚本、COMPLETION/FINAL_SUMMARY 等报告：有价值的历史归档 docs/archive，其余明确不用后删除；脚本保留实际工程管理入口。
- docs 教学与重复架构报告、旧 openspec 变更：归档而非混在当前决策入口；当前文档只保留有效合同。
- OpenClaw UI 树/live overlay、Smart 屏幕推荐：固定 workflow 不依赖时移除真实入口、类型、设置、测试与 target 引用。
- Langfuse 同步、Tracing/OpenTelemetry/gRPC、Google AI SDK：先区分 remote tools、可选 tracing 与用户已配置 provider，核验需求/调用后减依赖；有默认联网行为的配置须改为明确选择。
- 重复迁移、仓库合同、受控/非受控单例、无人调用的同步权限接口：随着入口切换直接删除。

每主题一份可审查改动；文件/依赖删除后更新工程并进行 focused build/tests。原 checkout 与用户数据保留恢复路径，不移动整个工程/会话目录。

### 阶段 6：可选语义检索（P3）

只有前面流畅度与正确性验收后才排期。先做真实样本检索评估，若关键词已足够则不增加 embedding 常驻成本。

## 拟定性能预算（不是已测结果）

以阶段 0 指定的一台基准机器 Release 构建为准，标准 200 条 + 500 条混合历史，额外 5,000 条只作扩展压力 fixture，不暗改用户默认上限。

| 场景 | 拟定验收目标 | 证据 |
|---|---|---|
| 暖启动快捷键到可交互首屏 | p95 ≤100 ms | 同设备 30 次 signpost 与 UI trace |
| 冷缓存首屏 | p95 ≤200 ms，图片后到不阻塞操作 | 清预览缓存后的首屏 trace |
| 搜索稳定输入到结果 | p95 ≤150 ms，含拟定 100 ms debounce | query generation 与发布 signpost |
| 复制后持久化 | p95 ≤200 ms，后台 OCR 单独计时 | capture/save signpost；连续复制无丢失 |
| 60Hz 连续滚动 | 帧预算 16.7 ms，hitch time ratio 拟定 <1% | UI trace，报告 p95/最大帧与长任务 |
| Idle 60 秒 | CPU 平均拟定 <1%，无截图/AX 树采集/索引轮询 | Time Profiler / wakeups；记录条件 |
| 预览缓存与后台工作 | 初始 32 MiB 缩略图预算，任务并发有界 | decoded cost、队列峰值、Allocations |

这些预算需基线校准；记录实际峰值 RSS，不能把 NSCache.totalCostLimit 当作整个进程的硬上限。若目标不可达，说明真实来源并调整方案，不用更长动画遮挡等待。

## 官方研究与限制

- Apple Doc MCP 已优先使用：SwiftUI/Image I/O 技术选择成功；drawingGroup/性能文章加载返回 404，缩略图文档加载 TLS 失败，未将失败当作 API 不存在。
- Context7 三次 library 查找：SQLite.swift 成功、SwiftUI 成功、Apple ImageIO 未命中；两次 query 获取 SQLite 显式列/分页与 Apple drawingGroup 官方内容。ImageIO 改用 Apple 官方来源核验。
- 依据 [Apple WWDC25 Instruments](https://developer.apple.com/videos/play/wwdc2025/306/) 建立 body 更新与因果测量；[drawingGroup](https://developer.apple.com/documentation/swiftui/view/drawinggroup(opaque:colormode:)) 只是离屏合成，不能一律称 GPU 加速；[SQLite.swift 官方文档](https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md) 支持显式列与分页。
- ImageIO 缩略图候选依据 [Apple 官方像素上限](https://developer.apple.com/documentation/imageio/kcgimagesourcethumbnailmaxpixelsize) 与 [Apple WWDC18 图像最佳实践](https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf)；实施前核验完整参数、方向、缓存策略与当前 SDK。
- 本轮未运行 app、未 Instruments profile、未 build/tests；因此没有改善幅度、FPS 或瓶颈排名的实测结论。目录无 .git，无法提供 Git diff/分支/提交；保留文件备份与独立文本 diff。

## Agent 指导文档整理

全局 AGENTS 从 200 行压缩为 42 行，保留安全边界、spec、官方事实、Xcode 会话发现、验证与可恢复交付。LifeNotes 专属 D39/D40 完整迁至全局 references，其他项目不默认载入。cc-switch 的唯一 enabled Codex prompt 原为旧 Claude 规则，包含固定五轮检索和旧工具调用名；已备份后条件更新 content，与运行时全局 AGENTS 完全一致，未改 provider、MCP、auth 或其他 settings。

项目 AGENTS 改为实际文件地图，移除错误版本、未证实工具路径和机械查询要求。规则依据冗余/冲突/证据精简，不把 GPT 型号升级当作删除安全约束的理由。历史 ADR 保留并追加 superseding decision，不悄悄改写历史。
