# 链接筛选

目标：增加“链接”分类按钮，默认开启，可在设置的分类筛选中关闭；使用现有圆形按钮与动效。
规则：文字摘要中包含 http://、https:// 或 www. 开头且具有有效域名的网页地址时归入链接；文字分类仍保留这些记录。仅做本地识别，不访问网页、不改变原文或存储类型。
非目标：链接抓取、网页预览与数据库迁移。
验证：检查所有分类 switch 完整；正反例校验域名、正文嵌入链接与邮件排除；运行一次 focused build。使用既有稳定签名安装并检查界面；不改变应用身份或权限。

## 2026-10-30 验证
- 官方 mcpbridge 返回无可用 XcodeService，改用 xcodebuild focused Debug build；BUILD SUCCEEDED。
- 链接识别 8 个正反例通过，证据位于 out/2026-10-30-link-filter/。
- 使用原 Apple Development 身份安装，签名校验通过。
- CUA 读取 /Applications/SenseFlow.app 实际界面，存在“链接”按钮，选中状态下列表显示链接记录。没有将用户剪贴板内容写入项目证据或提交。
