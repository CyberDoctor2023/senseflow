# 应用更新修复

目标：恢复默认自动检查（启动及每天一次，可关闭），仅提示、由用户确认下载和安装；保留手动检查。发布 0.6.5，后续以 0.6.6 补齐菜单栏常驻应用的可见提醒，统一 Bundle、DMG、GitHub 最新正式发布与带 EdDSA 签名的 appcast。包含此前删除一组工具的改动。

提醒合同：按 Sparkle gentle reminders 官方 delegate 实现；系统允许立即显示时由 Sparkle 展示，否则保留菜单栏图标与“发现新版本”入口，在用户回到应用时显示标准更新窗口，收到用户注意或结束会话后清除。无需申请通知权限，不强抢其他应用焦点。

非目标：不降级、不静默安装、不更换本机签名身份、不重置辅助功能授权，不修改历史或草稿。

现状：0.6.4 预发布不含 appcast，latest 指向 v0.6.2，其 feed 实际描述 0.6.0/build 7；旧代码启动时强制关闭自动检查。新策略替代 2026-10-14 仅手动检查的约定。

实现：Sparkle 负责版本比较、调度、提示和安装。仅一次迁移撤销旧代码强制关闭的状态，之后尊重用户开关；不存第二份自动检查偏好。CI 校验实际 Bundle 版本/构建号、Team、feed 中版本/大小/下载链接及公钥签名，成功后才发布到 latest。

验收：focused build；隔离实际 Sparkle 初始化/偏好关闭后重启验证；发布校验器拒绝不匹配或篡改包；CI 完成并核验线上 appcast/附件；原身份安装本机并检查设置及更新结果。两版本真实安装若未完成须明确记录，不能用编译替代。

## 本轮证据

- focused Debug build 成功：`out/2026-10-31-updater-fix/build.log`。
- 从当前生产源码提取未修改的 AppUpdateService 进行隔离运行，首次迁移启用检查、关闭后第二次启动仍关闭通过；下载保持关闭。测试产物均在上述 out 目录。
- 归档校验器接受有效 Ed25519 签名，拒绝错标签、错构建号、错 URL 和篡改归档。测试密钥为一次性生成，未读取生产私钥。
- GitHub Actions 41093863143 成功，发布 v0.6.5 为 latest；公开 latest/download/appcast.xml 的版本为 0.6.5/build 2026103101。线上下载 DMG 再次通过公钥签名、实际 Bundle 元数据和严格代码签名验证。
- 本机已覆盖安装并启动 `/Applications/SenseFlow.app` 0.6.5，证书 C8A15D08A9F9F23BF9B9553FF78AE6D72770B1D6，Team FPVWZ792P2；新旧 designated requirement 一致，未重置 TCC/数据库。
- 隔离旧版本检查在真实 Sparkle 窗口显示“0.6.5 可供下载，现在版本 0.6.4”。误在该隔离程序尝试安装会因宿主名 UpdateVerification.app 与归档 SenseFlow.app 不同而拒绝（日志明确 searched UpdateVerification.(app|pkg) / no suitable install），不能将此解释为生产 Ed25519 签名失败。已关闭验证进程。后续同名安装验证遇到 CUA timeout/ScreenCaptureKit -3811，停止该测试并恢复正式应用；不宣称已完成 Sparkle 两版本安装/重启。
- 已补测完整 Sparkle 安装：使用官方 SPUUserDriver API 自动驱动测试宿主（同名 SenseFlow.app、同 bundle ID、同签名、旧版本 0.6.4，独立 out 路径），真实从线上下载 0.6.5。日志包含“OK: EdDSA signature is correct for update”，依次完成提取、ready、installing，宿主退出后 Sparkle 以 0.6.5 正式二进制替换并自动重新启动；版本、二进制 cmp、严格签名核验通过。未覆盖正式应用为旧版本。证据 `out/2026-10-31-updater-fix/installation-api-test.log`；已终止测试副本并恢复 /Applications 正式应用。
- Sparkle 日志提示后台常驻应用未实现 gentle reminders，已在 0.6.6 补齐官方 delegate 与菜单栏提示，不再仅依赖藏在后台的窗口。
