# 手动添加文件到 Xcode 项目

由于 xcodeproj gem 的路径问题，请手动在 Xcode 中添加以下文件：

## 需要添加的文件

### Domain/Protocols 组
1. `SenseFlow/Domain/Protocols/AITransport.swift`
2. `SenseFlow/Domain/Protocols/APIRequestRecorder.swift`

### Infrastructure/Transport 组（新建）
3. `SenseFlow/Infrastructure/Transport/RealAITransport.swift`
4. `SenseFlow/Infrastructure/Transport/LoggingAITransport.swift`

### Infrastructure/Recorders 组（新建）
5. `SenseFlow/Infrastructure/Recorders/InMemoryAPIRequestRecorder.swift`

## 操作步骤

1. 打开 Xcode 项目
2. 在左侧导航栏找到 `SenseFlow/Domain/Protocols` 文件夹
3. 右键点击 → Add Files to "SenseFlow"
4. 选择 `AITransport.swift` 和 `APIRequestRecorder.swift`
5. 确保勾选 "Copy items if needed" 和 "Add to targets: SenseFlow"
6. 点击 Add

7. 在 `SenseFlow/Infrastructure` 下创建 `Transport` 文件夹
8. 右键点击 Transport → Add Files
9. 选择 `RealAITransport.swift` 和 `LoggingAITransport.swift`

10. 在 `SenseFlow/Infrastructure` 下创建 `Recorders` 文件夹
11. 右键点击 Recorders → Add Files
12. 选择 `InMemoryAPIRequestRecorder.swift`

13. 编译项目：Cmd+B

## 或者使用命令行

```bash
# 回退项目文件
git restore SenseFlow.xcodeproj/project.pbxproj

# 在 Xcode 中打开项目
open SenseFlow.xcodeproj

# 然后按照上面的步骤手动添加文件
```

## 验证

编译成功后，在开发者选项中应该能看到"上次 API 调用详情"功能。
