# SenseFlow 工作入口

原生 macOS 剪贴板：方便找回与预览，快捷键执行自定义工具。SwiftUI 内容 + AppKit 窗口 + SQLite；实际部署版本查工程 target，勿照抄旧文档版本。

## 任务入口

1. `docs/SPEC.md`：产品基础规格。
2. `docs/REFACTOR_SPEC_2026-10-06.md`：本次重构范围与验收，覆盖旧色条/预览/性能宣称。
3. `docs/REFACTOR_PLAN_2026-10-06.md`：代码审查、分阶段实施与风险。
4. 长文本核心合同：`docs/prd/LONG_TEXT_DOCUMENT_PREVIEW.md` 与 `docs/design/LONG_TEXT_DOCUMENT_PREVIEW.md`（hover 阅读、编辑、草稿与保存；优先于工具/RAG）。
5. `docs/TODO.md`、`docs/DECISIONS.md`：当前进度与决策；历史完成记录不能替代本轮证据。
6. `docs/refs.md`：外部事实引用。

## 开发与验证

- 实现前更新规格；已有 OpenSpec 流程按需使用，不依赖不存在的 slash command。
- Apple API 先查询 Apple Doc MCP；第三方依赖优先 Context7。找不到时记录限制，查询官方替代来源，不机械规定检索次数。
- 优先解决主线程阻塞、重复加载、无界后台任务，再调动画/视觉参数；性能结论必须有同设备前后数据。
- 卡片渲染不做磁盘、SQL、图片解码或全文分析；保存原文/原图，轻量预览按需加载。
- 用户界面不露 AX 节点和内部 trace；保留自动粘贴/按需取词所需 Accessibility。
- 不回退用户修改；数据迁移/删除前备份；生产重构不保留无删除条件的平行旧链路。
- 版本号来自 Bundle；公共 API 写文档注释。新增/删除文件时同步工程 target membership 与测试引用。
- 本轮审查与文档整理不主动构建。后续产品实现完成后，按已批准的验证计划运行最小 focused build/tests 与必要的 UI/性能实测，不无故反复全量构建。
- 有 Git 才创建专用分支并小步提交；提交前审查，不跳过 hooks。2026-10-08已按用户要求建立本地Git仓库；当前分支与提交状态以git实际输出为准。

整体重构当前入口：`docs/PROJECT_REFACTOR_2026-10-08.md`。

## 按需参考

- `docs/INSTRUMENTS_GUIDE.md`：已有性能测量流程（使用前核实是否适合当前工程）。
- `docs/GIT_HOOKS_GUIDE.md`：hooks 历史说明，先检查当前 checkout 是否实际安装。
- `openspec/`：历史变更与规格；不要当作活跃功能清单。
- `out/2026-10-06-refactor-review/`：本轮原始规则备份与审查证据。

更新：2026-10-06。规则精简依据重复、冲突和可验证性，不能用模型升级作为免除数据保护或验证的理由。

## 测试克制

- 只为真实风险和回归保留最小必要测试；不机械测试常量、简单转发或每个函数。
- 删除无断言占位、固定 Mock 重复循环及 Mock 计时伪性能测试；不能靠删失败测试宣称通过。
- 保留崩溃、原文/草稿安全、异步竞争、隐私和外部副作用覆盖；界面与性能用实际运行证据。
- PRD 验收编号和设计候选测试名称不是测试数量要求。详见 `docs/TEST_CLEANUP_2026-10-06.md`。
