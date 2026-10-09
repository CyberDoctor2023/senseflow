# Proposal: Expand multi-platform PM research coverage for SenseFlow and competitor issue signals

## Why

当前项目需要把已有需求挖掘从单平台补成可交叉验证的证据层：
1. Reddit 语料需要继续补采，目标是尽量接近或达到 2000 条原始记录。
2. 需要同步补 GitHub issues、YouTube、TikTok，形成 baseline / aligned / expanded 的多平台证据结构。
3. 需要单独调研竞品 `PasteNow`、`Deck` 的 GitHub issue 讨论，补充“官方问题面”和 workaround 信号。

如果不先固定范围和完成条件，这次工作很容易退化成零散抓数，最终无法判断采集是否闭环。

## What Changes

- 为本次研究创建一个项目内的、可追踪的多平台 run
- 明确 Reddit / GitHub / YouTube / TikTok 的采集入口、时间窗和输出位置
- 将 `PasteNow` 与 `Deck` 的 GitHub issue 采集视为独立竞品证据层
- 在完成扩采后，更新清洗、标注、跨平台汇总和最终交付物

## Non-Goals

- 不在本次 change 内修改 macOS 应用产品代码
- 不把 expanded 平台的数量直接混入 strict cross-check 结论
- 不在缺少凭证时伪造 TikTok / YouTube 数据

## Completion Conditions

- 项目目录内存在新的研究 run，包含 `collection_plan`、`round_tracker` 与平台原始输出
- Reddit 原始语料达到尽可能高的补采结果，并明确报告是否达到 2000 条及阻塞原因
- GitHub target/competitor issue 数据、YouTube 评论数据、TikTok 评论数据都有可追溯输出或明确失败记录
- Round 3 以后所需的清洗/标注/汇总结果与覆盖摘要已更新
- 最终资产写回项目内 `out/...`，而不是只留在临时目录

## Validation Plan

- 使用工作流脚本生成并检查 run scaffold、coverage summary、round tracker
- 校验各平台原始 JSON 是否存在、计数是否可复核、来源字段是否完整
- 对 Reddit / GitHub / 视频评论语料进行去重与平台分布检查
- 汇总最终达到的条数、平台覆盖、失败批次和剩余缺口

## Impact

- Affected specs: `research-demand-mining`
- Affected code: project-local research outputs under `out/`, `docs/refs.md`
