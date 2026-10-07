# 测试精简审查 · 2026-10-06

## 目标与边界

删除不能约束真实产品行为的冗余测试及无人使用的辅助文件，同步 Xcode 引用。保留错误传播、隐私、快捷键副作用和执行流程覆盖。此轮不改产品实现、不批量重写历史测试、不运行构建或 XCTest。

## 删除依据

| 文件/测试 | 依据 |
| --- | --- |
| PerformanceTests.swift（7 项） | 计时 Mock 和协调器调用，不能证明真实数据库、OCR、列表或长文本性能；所谓内存测试实际使用耗时指标。 |
| WindowLayoutConfigTests.swift（8 项） | 参数化模拟屏幕实际返回当前真实屏幕，尺寸输入无效；其余主要检查固定常量、算术和旧双窗口布局。 |
| MockWindowLayoutConfig.swift | 无调用方的辅助实现。 |
| restoreDefaultTools_callsRepository | 无断言，未验证所声称的仓库调用。 |
| classify_sameXiaohongshuTitleScenario_isStableAcross20Runs | 相同输入重复调用确定性分类器，已有单次分类覆盖。 |
| recommendTool_sameSceneAcross20Runs_keepsStableSelection | Mock 固定返回结果，重复 20 次不能证明真实模型稳定性；保留解析和跨请求隐私覆盖。 |

共删除 18 个测试声明、3 个文件。备份与实际验证记录保存在 `out/2026-10-06-test-cleanup/`。

## 最小必要验证策略

- 每项自动化测试对应明确产品风险、已知回归或真实边界；不为每个函数、固定常量、简单转发和视觉样式机械新增测试。
- 同类场景优先合并；禁止无断言占位、固定 Mock 重复循环和将 Mock 计时当产品性能证据。
- 保留崩溃、原文保护、草稿恢复、异步竞争、隐私和外部副作用的必要覆盖；不能靠删除失败测试宣称通过。
- 长文本 PRD 的验收编号代表产品行为，不要求每条变成单独单元测试。设计中的测试名称是候选场景。
- 后续实现优先覆盖 OCR continuation 恰好完成一次、源记录与草稿存储、保存代次竞争和会话切换；输入法、撤销及焦点通过原生界面实测；流畅度使用真实长文本、数据库和性能轨迹测量。

## 完成条件与验证计划

备份可恢复；删项与依据一一对应；工程仅移除相应文件/编译引用；保留源码可语法解析；产品 Swift 文件无变化。静态检查不能替代构建、XCTest 或运行性能测量。

## 已有问题

历史执行工具测试仍使用 `aiService:`，生产初始化入口已变为 `aiTransport:`。这属于清理前的 API 漂移，应在后续工具实现阶段同步，不能用本次删项掩盖。SettingsModelTests 的工程收录及默认值断言也需要后续核对。

## 工程编辑参考

使用项目已安装的 Ruby Xcodeproj 移除文件及关联编译引用，按对象差异审查范围：[维护者 API 文档](https://www.rubydoc.info/gems/xcodeproj/Xcodeproj/Project/Object/PBXFileReference)。Context7 返回同名 Swift 库，与这里的 Ruby 库不符，未作为依据。
