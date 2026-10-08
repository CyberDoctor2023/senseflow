# 整体重构验收核对

当前结论：未完成整体验收。代码重构、组件风险验证和同机测量已有证据，录屏物理长按呈现与新起伏边界体验仍未验证。

| 要求 | 当前证据 | 结论 |
| --- | --- | --- |
| 保存源码、分阶段可回滚 | 本地codex/refactor-project-decoupling分支；d26c9ce基线与后续提交；无远端推送 | 已落实 |
| 摘要筛选与分页、刷新代际解耦 | ClipboardListViewModel；risk-stage16.log跨页筛选、搜索竞争、锁定内容断言 | 已验证 |
| 原件读取与媒体准备离开UI | HistoryMediaLoader；capture-stage7-full.log与capture-panel-stage23.log | 已验证相关行为 |
| 缩略图有限并发、缓存、取消 | ClipboardThumbnailLoader；risk-stage16.log共享、取消、两库隔离；thumbnail-metrics.json | 已验证 |
| 文档持久化与窗口分离 | SQLiteDocumentStore与DocumentWindowHost；document-stage25.log原文、草稿、切换、关闭再打开 | 最新完整回归通过；历史间歇失败保留 |
| 捕获导入、系统标记、原件安全 | SystemCaptureService/SystemCaptureFileImporter；capture-stage7-full.log | 已验证隔离原件与系统来源 |
| AI身份与生成并发隔离、诊断有界 | CodexAuthManager/AIService actor/InMemoryAPIRequestRecorder；risk-stage16.log | 已验证结构及边界；未发付费请求 |
| 教程与真实数据分离、共享主界面 | ClipboardTutorialRepository与协调器；tutorial-lifecycle-stage17.log | 原生流程命令验证通过；不冒充物理输入 |
| 删除闲置路径与工程同步 | Git删除记录、工程Sources、移除两个闲置tracing products；build-stage25.log | 已落实，保留实际HTTP tracing |
| 鼠标滚轮恢复、两套动效独立 | stage19实际输入日志、用户“现在好了啊”、scroll-stage19.log；classic/wave独立设置 | 滚轮已实机确认 |
| 起伏仅由卡片边界激活 | 3979d5c；build-stage21.log、stage21实际启动 | 视觉轨迹未验收 |
| 录屏长按系统快速预览 | 单/双面板隔离QLPreviewPanel可见断言通过；用户真实长按已记录入口/URL成功，stage27改用唯一原生会话，待实机呈现确认 | 未完成，不能由隔离结果宣称主程序修好 |
| 构建、运行与交付一致 | stage27运行版PID64055；原生会话构建/隔离验证通过；delivery-stage21为旧暂存 | 交付尚需最终同步并移除临时诊断 |

## 性能证据的范围

同机200摘要/2000次代码筛选读取由83.109967041s变为0.00058775s，仅证明已移除重复计算热点，不代表全应用帧率。16张2400×1600原件缩略图突发加载峰值RSS约275MiB降至约60MiB，暖加载耗时约43ms变为70–73ms，有限并发以吞吐换取内存与响应保护，不能宣称所有指标均加快。OCR批次旧峰值约357–380MiB、新约165–173MiB；暖总耗时接近。旧Vision请求已替换为原生异步RecognizeTextRequest，实际删除竞争验证通过。

## 保留的限制和收尾

- 当前生产编译仍为Swift5；三类既有非Sendable持有诊断未用unchecked Sendable掩盖，未扩大为全项目Swift6迁移。
- 日志与隔离数据位于out/2026-10-08-project-refactor；用户历史、录屏原件、授权、密钥和草稿未用于测试或删除。
- 临时Debug录屏日志已在stage27删除并重新构建；原生录屏会话与窗口池解耦。运行包有备份，禁止覆盖运行进程或强制丢弃编辑草稿。
- Apple文档查询受MCP索引匹配限制时采用官方来源并记录于refs.md；官方Xcode bridge不可用，构建使用已记录的xcodebuild替代链。

最终验收还需要实际录屏长按入口与系统窗口呈现证据、起伏边界视觉反馈、无诊断运行包及最终源码/交付清单核对。本表不勾选总体完成。
