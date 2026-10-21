# 历史工程迁移脚本

这些脚本用于过去一次性的 Xcode 文件引用修补、重命名与测试 target 初始化，不属于当前构建、应用运行或验证链。当前工程引用直接维护在 `SenseFlow.xcodeproj/project.pbxproj`。

保留原始文件内容与原目录分组供追溯，历史文档中的原路径应在此查找。不要作为日常构建前置步骤运行：脚本包含针对旧工程结构的删除/重建操作。唯一当前文档会话验证入口仍是 `scripts/verify-document-workflow.sh`。
