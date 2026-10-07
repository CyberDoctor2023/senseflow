---
name: release-prep
description: 检查发布前的准备清单
---

# Release Preparation

发布 SenseFlow 新版本前的完整检查清单。

## 检查清单

### 1. 代码质量
- [ ] 所有 TODO 注释已解决
- [ ] 没有 Debug 日志输出
- [ ] 没有强制解包 (!)
- [ ] 公共 API 有文档注释

### 2. 功能测试
- [ ] 剪贴板自动捕获
- [ ] 全局快捷键（Cmd+Option+V）
- [ ] 搜索功能（文本 + OCR）
- [ ] 自动粘贴
- [ ] 设置面板所有选项
- [ ] 开机自启动
- [ ] Prompt Tools 集成

### 3. 性能指标
- [ ] CPU 占用 < 0.1%
- [ ] 数据库查询 < 50ms
- [ ] 搜索响应 < 10ms
- [ ] 动画 60fps

### 4. 权限检查
- [ ] Accessibility 权限提示正常
- [ ] Info.plist 权限说明清晰

### 5. 文档更新
- [ ] SPEC.md 版本号更新
- [ ] TODO.md 标记已完成
- [ ] CHANGELOG 添加更新日志
- [ ] README.md 同步功能列表

### 6. Git 提交
- [ ] 所有改动已提交
- [ ] 提交信息清晰
- [ ] 创建版本 tag

### 7. 构建
- [ ] Release 配置编译通过
- [ ] 签名和公证（如需分发）

## 使用方法

```
/release-prep
```

AI 将逐项检查并生成报告。

## 输出示例

```markdown
## 发布准备检查

✅ 代码质量: 通过
✅ 功能测试: 8/8 通过
⚠️  性能指标: 动画帧率 55fps (略低于目标)
✅ 权限检查: 通过
⚠️  文档更新: CHANGELOG 未更新
✅ Git 提交: 干净
✅ 构建: Release 编译成功

### 需要处理的问题:
1. 更新 CHANGELOG.md
2. 优化窗口动画帧率
```
