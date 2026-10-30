# SenseFlow 闪退证据与 P0 修复计划

日期：2026-10-06。状态：真实崩溃已确认；本地高可信缺陷已定位，修复与复现验证尚未进行。

## 实际证据

macOS 报告 `SenseFlow-2026-10-06-162942.ips`，timestamp 2026-10-06 16:29:42 +0800；应用 0.6.0 build 7，运行路径 `/Applications/SenseFlow.app/Contents/MacOS/SenseFlow`，系统 macOS 27.0.1 build 26A434。faultingThread=5，queue=`com.apple.root.utility-qos.cooperative`，exception=`EXC_BREAKPOINT / SIGTRAP`，termination=`SIGNAL / Trace/BPT trap: 5`。

堆栈前缀：

```text
libswiftCore._assertionFailure
libswift_Concurrency.CheckedContinuation.resume(returning:)
SenseFlow.closure #1 in OCRService.performRecognition(from:)
libswift_Concurrency.withCheckedContinuation
SenseFlow.specialized OCRService.recognizeText(from:)
SenseFlow.closure #1 in DatabaseManager.performOCR(for:imageData:)
```

原始报告和仅必要字段摘要保存于 `out/2026-10-06-crash-review/`。这是实际进程崩溃，不是只凭菜单栏消失推测。

## 根因边界

本地 `SenseFlow/Services/OCRService.swift:59–118` 的 `performRecognition` 用 checked continuation 包装 Vision 请求。request completion 的 error/空结果/成功分支均 resume；`requestHandler.perform` 的 catch 又 resume 同一个 continuation。

Swift 官方规定 continuation 每条路径只能恢复一次；checked continuation 重复恢复会 trap。报告中的断言位置与本地重复恢复结构高度吻合。具体触发 Vision 错误、两次恢复的先后、原图片尚未取得；不能虚构错误码或输入。本地源与安装包未进行 UUID/构建来源对应核验，报告确认的是安装包 OCR continuation 崩溃，源代码显示同类缺陷。

## 目标修复（优先于原性能阶段 1）

1. 移除同步 Vision perform 的重复 callback→continuation 桥接：由后台有界 OCR worker 执行请求，perform 完成后统一读取结果/错误并单次返回。使用当前官方 SDK 合同实现，不新增 unsafe continuation 或 try? 掩盖失败。
2. OCR 正常错误应成为结构化失败状态；不影响剪贴板捕获成功，不清空记录、不把识别失败变成进程退出。记录非敏感错误 domain/code、job ID 和请求阶段，不记录用户原文/图片内容。
3. OCR 任务有并发上限和取消/退出所有权；重复图片复用已有结果，失败重试有边界。保留自动后台识别能力，而非关掉 OCR 宣称修好。
4. 应用生命周期保存未完成会话标记，正常退出清理；下次启动若发现异常会话，显示一次“上次未正常结束”与查看/导出诊断入口。标记不能单独区分 crash、强制退出和断电，不据此显示确定的“发生崩溃”。尊重用户明确退出，不无限自动重启。
5. 本轮不增加后台 watchdog/登录代理。致命 trap 后同一进程无法可靠弹出自己的提示；反馈放在下次启动及可恢复的普通 OCR 错误路径。涉及系统 crash/生命周期行为的实现前再次查 Apple 官方文档。

## 验收

先核验安装包与源对应关系，脱敏建立可复现 OCR 失败 fixture；测试正常识别、无文字、损坏图片、Vision 执行失败、连续复制图、取消与退出。建议 focused tests：`testOCRRequestFailureReturnsWithoutTerminating`、`testOCRFailureDoesNotDiscardCapturedImage`、`testRepeatedImageCaptureReusesOCRResult`、`testUncleanSessionNoticeAppearsOnlyOnce`。测试须经过真实 OCR worker 的执行路径，不仅测试假 reducer；如果仍有桥接，加入 callback 与 perform error 同时发生的回归验证。

focused build/tests 与 Release 实测通过，失败 OCR 不终止进程，原图/历史保留，诊断错误字段可核对，才可将修复标为完成。短时未再崩溃不能证明已根治；记录操作次数、持续时间与新 crash report 对比。

## 参考

- [Apple CheckedContinuation](https://developer.apple.com/documentation/swift/checkedcontinuation)：每条路径仅恢复一次。
- [Swift 标准库实现](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/CheckedContinuation.swift)：重复恢复的 fatalError/trap 机制。
- [Apple Vision perform](https://developer.apple.com/documentation/vision/vnimagerequesthandler/perform(_:))：Apple Doc MCP 查证；[官方同步 perform 示例](https://developer.apple.com/documentation/vision/detecting-objects-in-still-images)。

本轮仅读取 macOS 报告、检查代码和更新计划，未修改产品代码、未构建或启动应用，未自动上传报告。
