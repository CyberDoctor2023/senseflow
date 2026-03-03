---
name: build-check
description: 验证项目构建和核心功能
---

# Build Check

验证 SenseFlow 项目的构建状态和核心功能。

## 执行步骤

1. **编译项目**
   ```bash
   xcodebuild -scheme SenseFlow -configuration Debug
   ```

2. **检查编译产物**
   - 确认 `DerivedData/SenseFlow-.../Build/Products/Debug/SenseFlow.app` 存在

3. **验证核心功能**（如果应用正在运行）:
   - 剪贴板监听是否工作
   - 快捷键是否响应
   - 搜索功能是否正常
   - OCR 功能是否可用

4. **性能检查**:
   - CPU 占用 < 0.1%
   - 数据库查询 < 50ms

## 使用方法

```
/build-check
```

AI 将自动执行上述检查步骤并报告结果。

## 输出示例

```
✅ 编译成功
✅ CPU 占用: 0.05%
✅ 数据库查询: 32ms
⚠️  警告: 未检测到应用运行
```
