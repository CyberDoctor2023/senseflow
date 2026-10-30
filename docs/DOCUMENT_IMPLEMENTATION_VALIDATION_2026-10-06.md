# 长文本第一阶段：实施与验证

日期：2026-10-06。状态：实现与构建完成，已有 focused 证据；真实卡片修正后的最终重跑和完整产品验收待完成。没有 Git 元数据，未创建分支或提交。未替换用户已安装应用。用户随后要求运行真实应用：已备份既有数据库，开发构建已启动，并完成草稿表迁移快照。

## 已落地

- 卡片取消文字/图片色条与重动画；按有界摘要判断是否溢出。350ms hover 意图打开单一原生 NSPanel，窗口按内容样本/可见屏幕调整，全文在 TextKit 2 NSTextView 内滚动。按钮/Space 为替代入口；点击进入固定编辑，支持撤销、查找、字号和等宽显示。
- DocumentPreviewCoordinator 管会话、请求身份、编辑代次和保存；NativeDocumentEditor 单独持有实时正文，SwiftUI 不绑定全文。DocumentWindowHost 管焦点和窗口，WorkspaceWindowCoordinator 统一历史/文档归属，HistoryActionCoordinator 将预览与粘贴分离。
- DatabaseManager 单一串行队列拥有同一连接；捕获写入、摘要/全文读取、草稿、版本、旧工具入口都服从这一所有者。列表只读取至多1025字符摘要，不携带图片 BLOB；缩略图在独立 loader 内生成和限额缓存。重复捕获保留稳定 ID，裁剪按明确 ID 删除。
- 独立草稿按空闲1秒/最长5秒 checkpoint，标记文本期间不提交。保存产生新记录或复用内容相同的记录，原文保持不变；写入回执不覆盖随后输入。关闭提供保存、保留草稿、放弃与取消，失败保持文档。
- 添加草稿/版本表前，对真实既有数据库执行本地迁移快照；本轮只验证隔离数据库，用户随后要求运行应用，启动前另作数据库备份，迁移快照已产生。
- 删除用户可见 AX 诊断覆盖层，保留自动粘贴所需 Accessibility。OCR 改为 actor 内同步 Vision 请求单次归集结果，删除已知双恢复崩溃路径。异常会话在下次启动提供本地诊断入口，不上传内容。

## 验证证据

环境：本机 Apple arm64，macOS 27.0.1，Xcode beta，工程目标 macOS 15.6，Debug。

- 官方 Xcode bridge 已发现窗口、SenseFlow scheme 与 My Mac destination；BuildProject 被账号/签名证书缺失阻挡。原始日志：`../out/2026-10-06-document-implementation/official-xcode-signing.log`。
- 后备无签名开发构建成功：`../out/2026-10-06-document-implementation/build-verified.log`。这不代表可分发签名版完成。构建仍有现存服务/适配器的 Swift 6 隔离与 Sendable 警告，未把 Debug 编译成功视为严格并发迁移完成。
- `Tests/DocumentWorkflowVerification.swift` 通过脚本加载上述实际应用模块，使用临时 SQLite 和真实 AppKit 编辑器。早前真实 SQLite/AppKit 验证通过；后续真实卡片体验发现摘要SQL被当成字符串标识符显示。已改为 literal 表达式，并补实际原文前缀断言；该断言首次用 Swift grapheme hasPrefix 时遇到 SQLite 在组合字符内截断，现改为 UTF-8 前缀比较。当前最终 focused 日志尚需重跑，不宣称最后一轮全部通过。没有添加一套机械 XCTest；只覆盖正文/草稿安全、异步保存竞争、Unicode/IME 和已知崩溃风险。
- 真实数据库验证：摘要上限、完整原文、重复捕获保留 ID、派生保存幂等/去重、原文不变、旧代次 checkpoint/discard 被拒绝、重新建立 store 后恢复落盘草稿。
- 真实 AppKit 验证：109200 UTF-16 长度全文载入、阅读不成为 key、编辑固定不被另一个 hover 替换、Unicode 编辑与 undo/redo、marked text 时拒绝保存、显示选项不重建 text storage、复制不隐式归档、保存中继续输入不被旧回执覆盖。
- 1350000 UTF-16 长度压力正文完整载入；本次显式打开等待测量约33.37ms，轮询间隔20ms，只是单次 Debug 诊断，不是首屏 p95 或输入延迟预算验收。
- Vision 对真实空白图片4次返回空结果，坏图片返回可恢复失败；没有 continuation 路径。未模拟/声称覆盖所有系统 Vision 异常。
- 仅捕获验证窗口的视图截图：`../out/2026-10-06-document-implementation/verification/document-preview.png`，不含用户数据。

## 同设备存储路径对照

隔离库中43条记录，主要为约109k字符正文；同进程热缓存交替读取12次。早前投影表达式有误，该轮读取耗时不能作为有效摘要性能结论，必须修正后重测。原始每次耗时、测量范围见 `../out/2026-10-06-document-implementation/verification/metrics.json`。

不使用上述失效对照宣称性能改善。未测 Release、滚动帧率、键入 p95、峰值 RSS、真实鼠标 hover 首屏。

## PRD 验收状态与剩余风险

| 合同 | 本轮证据 | 待完成 |
|---|---|---|
| LT-01/02/03 | 原生窗口、350ms前移出候选不打开窗口已验证；最新身份检查已实现 | 真实鼠标快速划过、跨间隙、拖选，延迟加载竞争实测 |
| LT-04/05 | 固定会话、原文/保存/复制及保存期间输入通过 | 完整应用焦点切换体验 |
| LT-06 | Unicode、undo/redo、marked text 拒绝提交通过 | 真实中文输入法、查找 UI 手动体验 |
| LT-07 | 草稿落盘、重新打开 store、旧代次拒绝通过 | 磁盘故障注入、退出对话框与异常进程重启实测 |
| LT-08 | workspace 归属和屏幕尺寸适配已实现 | 真实多屏/窗口焦点验证 |
| LT-09 | 109k编辑、1.35M完整载入与数据库对照通过 | Release 首屏/输入 p95、RSS/帧率/任务数 |
| LT-10 | 文档依赖本地 store；隔离验证没有联网或用户剪贴板写入 | 完整应用网络/屏幕捕获审计 |

桌面截图服务曾返回 ScreenCaptureKit -3812，重置后恢复并验证了真实长/短文卡片、修复后的正文摘要及全文按钮；后来又返回 -3811，未完成真实 hover 轨迹验收。用户要求自行体验，已停止隔离体验窗口并启动实际开发构建，进程38994，既有数据库启动前另有本地备份。

历史裁剪后孤立草稿的独立找回入口、捕获队列背压、OCR待处理任务上限、工具/RAG 后台隔离与其他旧路径清理仍待后续阶段；不能称全面性能优化已完成。历史工具测试入口漂移仍按 `TEST_CLEANUP_2026-10-06.md` 跟进。

## 复现

使用现有无签名 Debug 构建产物执行 `scripts/verify-document-workflow.sh <Debug产品目录> <隔离输出目录>`。测试创建独立数据库，脚本不会替换应用或读用户历史。源码/工程修改前备份在 `../out/2026-10-06-document-implementation/before/`。

## 后续修订状态

用户要求改为无边框中央玻璃浮层，图片同样展开，删除文档工具栏并支持滚轮横向历史。修正摘要表达式后的focused完整重跑已通过，最新证据见 `GLASS_PREVIEW_VALIDATION_2026-10-06.md`；此文较早窗口样式和重跑待办仅作历史记录。
