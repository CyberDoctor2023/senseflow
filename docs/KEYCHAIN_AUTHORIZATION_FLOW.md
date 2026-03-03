# Keychain 授权弹窗触发逻辑

本文档详细说明 Keychain 授权弹窗在什么时候、什么情况下会触发。

---

## 🔑 触发时机总览

| 场景 | 触发时机 | 授权次数 | 说明 |
|------|---------|---------|------|
| **首次启动（无主密钥）** | Settings 打开时 | 1 次 | 生成并保存主密钥 |
| **正常启动（有主密钥）** | Settings 打开时 | 1 次 | 读取主密钥 |
| **切换服务** | 无 | 0 次 | 从内存缓存读取 |
| **保存新 API Key** | 点击保存时 | 0 次 | 主密钥已缓存 |
| **Debug 重新构建** | Settings 打开时 | 1 次 | 重新授权主密钥 |

---

## 📍 详细触发流程

### 场景 1: 首次启动（无主密钥）

**用户操作**:
```
1. 启动应用
2. 点击菜单栏图标 → Settings (或按 ⌘,)
3. Settings 窗口打开
```

**代码执行流程**:
```
PromptToolsSettingsView.onAppear
  ↓
loadAllKeys()
  ↓
KeychainManager.shared.getAllSettingsKeys()
  ↓
get(account: "openai_api_key")  // 第一次读取
  ↓
decrypt(encryptedData)
  ↓
getMasterKey()
  ↓
getMasterKeyFromKeychain()  // 返回 nil（首次启动）
  ↓
生成新主密钥: SymmetricKey(size: .bits256)
  ↓
saveMasterKeyToKeychain(keyData)
  ↓
SecItemAdd(query)  ⚠️ 【触发 Keychain 授权弹窗】
```

**弹窗内容**:
```
"SenseFlow" 想要访问钥匙串中的密钥 "com.senseflow.masterkey"。

[拒绝] [始终允许] [允许]
```

**用户选择**:
- **允许**: 本次授权成功，下次仍需授权
- **始终允许**: 本次和后续都不再提示（推荐）
- **拒绝**: 无法保存主密钥，功能失效

---

### 场景 2: 正常启动（有主密钥）

**用户操作**:
```
1. 启动应用
2. 打开 Settings
```

**代码执行流程**:
```
PromptToolsSettingsView.onAppear
  ↓
loadAllKeys()
  ↓
KeychainManager.shared.getAllSettingsKeys()
  ↓
get(account: "openai_api_key")
  ↓
decrypt(encryptedData)
  ↓
getMasterKey()
  ↓
检查内存缓存: cachedMasterKey == nil
  ↓
getMasterKeyFromKeychain()
  ↓
SecItemCopyMatching(query)  ⚠️ 【触发 Keychain 授权弹窗】
  ↓
缓存主密钥到内存: cachedMasterKey = key
  ↓
后续所有读取都从缓存获取（无需再次授权）
```

**弹窗内容**:
```
"SenseFlow" 想要访问钥匙串中的密钥 "com.senseflow.masterkey"。

[拒绝] [始终允许] [允许]
```

**关键点**:
- ✅ 只在**第一次读取**时触发
- ✅ 主密钥读取后**缓存在内存**
- ✅ 后续所有操作（切换服务、读取其他 keys）都从缓存获取

---

### 场景 3: 切换服务（无授权）

**用户操作**:
```
1. Settings 已打开
2. Prompt Tools → 切换服务: OpenAI → Claude → Gemini
```

**代码执行流程**:
```
onChange(of: selectedServiceRaw)
  ↓
loadAPIKeyFromCache()
  ↓
cachedKeys.apiKey(for: .claude)  // 从缓存读取
  ↓
✅ 无需访问 Keychain，无授权弹窗
```

**关键点**:
- ✅ 所有 API Keys 在 `onAppear` 时已批量读取并缓存
- ✅ 切换服务只是从缓存中取不同的 key
- ✅ **完全无需 Keychain 访问**

---

### 场景 4: 保存新 API Key（无授权）

**用户操作**:
```
1. Settings → Prompt Tools
2. 输入新的 API Key
3. 按 Return 保存
```

**代码执行流程**:
```
SecureField.onSubmit
  ↓
saveAPIKey()
  ↓
KeychainManager.shared.save(key: newKey, for: "openai_api_key")
  ↓
encrypt(newKey)
  ↓
getMasterKey()
  ↓
返回缓存的主密钥: cachedMasterKey  ✅ 已缓存
  ↓
AES.GCM.seal(data, using: key)
  ↓
UserDefaults.standard.set(encrypted, forKey: "encrypted_openai_api_key")
  ↓
✅ 无需访问 Keychain，无授权弹窗
```

**关键点**:
- ✅ 主密钥已在 Settings 打开时读取并缓存
- ✅ 加密使用缓存的主密钥
- ✅ 加密后的数据存 UserDefaults（无需授权）

---

### 场景 5: Debug 重新构建（需要重新授权）

**背景**: Debug 构建使用 ad-hoc 代码签名，每次构建签名会变化

**用户操作**:
```
1. Xcode 重新构建 (⌘B)
2. 运行应用
3. 打开 Settings
```

**代码执行流程**:
```
PromptToolsSettingsView.onAppear
  ↓
loadAllKeys()
  ↓
getMasterKey()
  ↓
getMasterKeyFromKeychain()
  ↓
SecItemCopyMatching(query)  ⚠️ 【触发 Keychain 授权弹窗】
  ↓
原因: 代码签名变化，Keychain ACL 不再识别应用
```

**弹窗内容**:
```
"SenseFlow" 想要访问钥匙串中的密钥 "com.aiclipboard.masterkey"。

此应用的签名已更改。

[拒绝] [始终允许] [允许]
```

**关键点**:
- ⚠️ Debug 模式每次重新构建都需要重新授权
- ✅ 但只需授权 **1 次**（vs 之前 3 次）
- ✅ Release 构建使用固定签名，不会有此问题

---

## 🔍 为什么只需 1 次授权？

### 旧方案（7 次授权）
```
Settings 打开:
  ├─ 读取 openai_api_key      → 授权 1
  ├─ 读取 claude_api_key      → 授权 2
  ├─ 读取 gemini_api_key      → 授权 3
  ├─ 读取 deepseek_api_key    → 授权 4
  ├─ 读取 openrouter_api_key  → 授权 5
  ├─ 读取 langfuse_public_key → 授权 6
  └─ 读取 langfuse_secret_key → 授权 7
```

### 新方案（1 次授权）
```
Settings 打开:
  └─ 读取主密钥 → 授权 1 ✅
     ↓ (缓存在内存)
     ├─ 解密 openai_api_key      (从 UserDefaults)
     ├─ 解密 claude_api_key      (从 UserDefaults)
     ├─ 解密 gemini_api_key      (从 UserDefaults)
     ├─ 解密 deepseek_api_key    (从 UserDefaults)
     ├─ 解密 openrouter_api_key  (从 UserDefaults)
     ├─ 解密 langfuse_public_key (从 UserDefaults)
     └─ 解密 langfuse_secret_key (从 UserDefaults)
```

**核心优化**:
- ✅ Keychain 只存 1 个主密钥
- ✅ 主密钥读取后缓存在内存
- ✅ 所有 API Keys 加密后存 UserDefaults（无需授权）

---

## 📊 授权次数对比

| 操作 | 旧方案 | 新方案 | 改进 |
|------|--------|--------|------|
| 打开 Settings | 7 次 | 1 次 | **-86%** |
| 切换服务 | 1 次 | 0 次 | **-100%** |
| 保存 API Key | 1 次 | 0 次 | **-100%** |
| Debug 重新构建 | 7 次 | 1 次 | **-86%** |

---

## 🐛 常见问题

### Q1: 为什么 Debug 模式每次都要授权？
**A**: Debug 构建使用 ad-hoc 签名，每次构建签名会变化。Keychain 通过代码签名识别应用，签名变化后视为"新应用"。

**解决方案**:
- 使用开发证书签名（非 ad-hoc）
- 在 Keychain Access 中设置"始终允许"
- Release 构建不会有此问题

### Q2: 如果用户点击"拒绝"会怎样？
**A**: 无法读取主密钥，所有 API Keys 无法解密，功能失效。

**解决方案**:
- 应用应检测授权失败
- 显示友好的错误提示
- 引导用户到系统设置授权

### Q3: 主密钥丢失怎么办？
**A**: 如果主密钥丢失（如用户删除 Keychain 项目），所有加密的 API Keys 无法解密。

**解决方案**:
- 检测主密钥丢失
- 提示用户重新输入 API Keys
- 生成新的主密钥

### Q4: 内存缓存安全吗？
**A**: 内存缓存在应用运行期间存在，应用退出后自动清除。

**安全性**:
- ✅ 缓存只在应用进程内可见
- ✅ 应用退出后自动清除
- ✅ 其他应用无法访问
- ⚠️ 内存转储可能泄露（极端情况）

---

## 🎯 最佳实践

### 用户操作建议
1. **首次授权时选择"始终允许"** - 避免重复授权
2. **不要在 Keychain Access 中手动删除主密钥** - 会导致数据无法解密
3. **Release 构建使用固定签名** - 避免重复授权

### 开发者建议
1. **使用开发证书签名** - 减少 Debug 模式授权次数
2. **添加授权失败处理** - 友好的错误提示
3. **考虑添加主密钥恢复机制** - 提高容错性

---

**最后更新**: 2026-01-29
