# GitHub 应用更新

> 历史记录：自动检查策略与发布合同已由 [2026-10-31 修复规格](UPDATER_FIX_2026-10-31.md) 替代。以下保留当时的决策与验证限制。

目标：设置内显示当前 Bundle 版本、手动“检查更新”入口；通过 Sparkle 官方更新器校验、下载、安装、重启。GitHub Releases 托管更新包与 appcast.xml，无新增服务器。工具更新服务与应用更新服务独立。

用户最终确认：仅手动检查，去掉自动检查与自动下载设置；后台不检查或下载。保留 Sparkle 标准版本比较、错误提示与签名验证，不自写覆盖应用脚本；不会回退到较旧版本或改变剪贴板数据库。非目标：发布尚未验证的新版本、修改工具或引导。

发布合同：更新包 EdDSA 签名，公开钥写入 Bundle，私钥仅 Keychain/GitHub Secret。CI 生成 appcast 并随 DMG 发布。旧 0.6.2 不含更新器，需手动安装首个含更新器的版本；之后支持手动应用内更新。

验收：focused build、更新器有效初始化、后台自动检查/下载关闭、正式 feed 在线可读且解析通过。安装验证必须使用两个有签名的不同版本，不能以“打开 GitHub”代替自动安装验证。记录未满足的发布/安装条件。

官方依据：
- https://sparkle-project.org/documentation/programmatic-setup
- https://sparkle-project.org/documentation/preferences-ui
- https://sparkle-project.org/documentation/

当前 GitHub 最新正式版 v0.6.2，本地 Bundle 配置 0.6.3/20261009。需保持这一差异可见，不为验证发布未测试版本。

## 实施证据

软件更新设置只显示当前版本与“检查更新”。AppUpdateService 独立于工具更新，启动时关闭自动检查/下载。Debug 构建与隔离初始化验证通过，线上签名 feed 解析、DMG 签名验证与 CI 语法检查通过。证据 out/2026-10-14-github-updates/VALIDATION.md。没有替换本地应用或发布新版本，真实两版本安装/重启留待正式发布验收。
