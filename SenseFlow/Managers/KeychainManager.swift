//
//  KeychainManager.swift
//  SenseFlow
//
//  Created on 2026-01-19.
//

import Foundation
import Security
import CryptoKit

/// Keychain 管理器（单例）
/// 采用 Deck 策略：Keychain 只存储 1 个主加密密钥，所有 API Keys 加密后存 UserDefaults
///
/// ## 架构设计
/// - **Keychain**: 只存储 1 个 AES-256 主密钥 → 只需授权 1 次
/// - **UserDefaults**: 存储加密后的 API Keys → 无需授权，快速访问
/// - **内存缓存**: 缓存解密后的 keys 和主密钥 → 减少重复解密
///
/// ## 优势
/// 1. **减少授权提示**: Keychain 访问从 7 次减少到 1 次（只读取主密钥）
/// 2. **Debug 友好**: 即使重新签名，也只需授权 1 次
/// 3. **性能优化**: UserDefaults 访问比 Keychain 快，支持批量操作
/// 4. **安全性**: 数据仍然加密存储，主密钥受 Keychain 保护
///
/// ## 数据迁移
/// 首次启动时自动检测旧的 Keychain 存储，迁移到新的加密存储
class KeychainManager {

    // MARK: - Singleton

    static let shared = KeychainManager()

    // MARK: - Constants

    // Keychain 配置（只存储主密钥）
    private let keychainService = "com.senseflow.masterkey"
    private let keychainAccount = "encryption-key"

    // UserDefaults 键名前缀
    private let encryptedKeyPrefix = "encrypted_"

    // 旧的 Keychain service（用于数据迁移）
    private let legacyKeychainService = "com.aiclipboard.apikeys"
    private let legacyMasterKeyService = "com.aiclipboard.masterkey"

    // API Key 标识符
    struct Keys {
        static let openaiAPIKey = "openai_api_key"
        static let claudeAPIKey = "claude_api_key"
        static let geminiAPIKey = "gemini_api_key"
        static let deepseekAPIKey = "deepseek_api_key"
        static let openrouterAPIKey = "openrouter_api_key"
        static let langfusePublicKey = "langfuse_public_key"
        static let langfuseSecretKey = "langfuse_secret_key"
    }

    // MARK: - Cache

    /// 内存缓存，避免频繁解密
    private var cache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "com.senseflow.keychain.cache")

    /// 主密钥缓存（避免重复访问 Keychain）
    private var cachedMasterKey: SymmetricKey?
    private let masterKeyQueue = DispatchQueue(label: "com.senseflow.keychain.masterkey")

    // MARK: - Initialization

    private init() {
        // 首次启动时检查是否需要迁移数据
        // 先迁移主密钥，再迁移 API keys
        migrateMasterKeyIfNeeded()
        migrateFromLegacyKeychainIfNeeded()
    }

    // MARK: - Master Key Management

    /// 获取或创建主加密密钥
    private func getMasterKey() -> SymmetricKey? {
        // 先检查内存缓存
        let cached = masterKeyQueue.sync { cachedMasterKey }
        if let cached = cached {
            return cached
        }

        // 尝试从 Keychain 读取
        if let keyData = getMasterKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            masterKeyQueue.sync {
                cachedMasterKey = key
            }
            return key
        }

        // 生成新密钥
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        if saveMasterKeyToKeychain(keyData) {
            masterKeyQueue.sync {
                cachedMasterKey = key
            }
            return key
        }

        return nil
    }

    /// 从 Keychain 读取主密钥
    private func getMasterKeyFromKeychain(service: String? = nil) -> Data? {
        let serviceIdentifier = service ?? keychainService
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }

        return nil
    }

    /// 保存主密钥到 Keychain
    private func saveMasterKeyToKeychain(_ keyData: Data, service: String? = nil) -> Bool {
        let serviceIdentifier = service ?? keychainService
        // 先删除已存在的
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 保存新密钥
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ 主加密密钥已保存到 Keychain")
            return true
        } else {
            print("⚠️ 保存主密钥失败，尝试 fallback: \(status)")
            // Fallback: 不带 accessibility 属性
            let fallbackQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceIdentifier,
                kSecAttrAccount as String: keychainAccount,
                kSecValueData as String: keyData
            ]
            let fallbackStatus = SecItemAdd(fallbackQuery as CFDictionary, nil)
            if fallbackStatus == errSecSuccess {
                print("✅ 主加密密钥已保存（fallback）")
                return true
            }
            print("❌ Fallback 也失败: \(fallbackStatus)")
            return false
        }
    }

    /// 从 Keychain 删除指定 service 的条目
    private func deleteFromKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Encryption/Decryption

    /// 加密数据
    private func encrypt(_ plaintext: String) -> Data? {
        guard let key = getMasterKey() else {
            print("❌ 无法获取主密钥")
            return nil
        }

        guard let data = plaintext.data(using: .utf8) else {
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("❌ 加密失败: \(error)")
            return nil
        }
    }

    /// 解密数据
    private func decrypt(_ encryptedData: Data) -> String? {
        guard let key = getMasterKey() else {
            print("❌ 无法获取主密钥")
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("❌ 解密失败: \(error)")
            return nil
        }
    }

    // MARK: - Public Methods

    /// 保存 API Key（加密后存 UserDefaults）
    /// - Parameters:
    ///   - key: API Key 值
    ///   - account: 账户标识（如 Keys.openaiAPIKey）
    func save(key: String, for account: String) -> Bool {
        guard let encryptedData = encrypt(key) else {
            print("❌ 加密失败: \(account)")
            return false
        }

        // 存储到 UserDefaults
        let storageKey = encryptedKeyPrefix + account
        UserDefaults.standard.set(encryptedData, forKey: storageKey)

        // 更新缓存
        cacheQueue.sync {
            cache[account] = key
        }

        print("✅ API Key 已保存（加密）: \(account)")
        return true
    }

    /// 读取 API Key（从 UserDefaults 解密）
    /// - Parameter account: 账户标识
    /// - Returns: API Key 或 nil
    func get(account: String) -> String? {
        // 先查缓存
        let cachedValue = cacheQueue.sync { cache[account] }
        if let cached = cachedValue {
            return cached
        }

        // 从 UserDefaults 读取加密数据
        let storageKey = encryptedKeyPrefix + account
        guard let encryptedData = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        // 解密
        guard let decrypted = decrypt(encryptedData) else {
            print("❌ 解密失败: \(account)")
            return nil
        }

        // 存入缓存
        cacheQueue.sync {
            cache[account] = decrypted
        }

        return decrypted
    }

    /// 删除 API Key
    /// - Parameter account: 账户标识
    @discardableResult
    func delete(account: String) -> Bool {
        let storageKey = encryptedKeyPrefix + account
        UserDefaults.standard.removeObject(forKey: storageKey)

        // 清除缓存
        cacheQueue.sync {
            cache.removeValue(forKey: account)
        }

        return true
    }

    // MARK: - Convenience Methods

    /// 获取当前服务类型的 API Key
    func getAPIKey(for serviceType: AIServiceType) -> String? {
        switch serviceType {
        case .openai:
            return get(account: Keys.openaiAPIKey)
        case .claude:
            return get(account: Keys.claudeAPIKey)
        case .gemini:
            return get(account: Keys.geminiAPIKey)
        case .deepseek:
            return get(account: Keys.deepseekAPIKey)
        case .openrouter:
            return get(account: Keys.openrouterAPIKey)
        case .ollama:
            return nil  // Ollama 不需要 API Key
        }
    }

    /// 保存当前服务类型的 API Key
    @discardableResult
    func saveAPIKey(_ key: String, for serviceType: AIServiceType) -> Bool {
        switch serviceType {
        case .openai:
            return save(key: key, for: Keys.openaiAPIKey)
        case .claude:
            return save(key: key, for: Keys.claudeAPIKey)
        case .gemini:
            return save(key: key, for: Keys.geminiAPIKey)
        case .deepseek:
            return save(key: key, for: Keys.deepseekAPIKey)
        case .openrouter:
            return save(key: key, for: Keys.openrouterAPIKey)
        case .ollama:
            return true  // Ollama 不需要 API Key
        }
    }

    /// 检查是否已配置 API Key
    func hasAPIKey(for serviceType: AIServiceType) -> Bool {
        if serviceType == .ollama { return true }
        return getAPIKey(for: serviceType) != nil
    }

    // MARK: - Langfuse Methods

    /// 获取 Langfuse Public Key
    func getLangfusePublicKey() -> String? {
        return get(account: Keys.langfusePublicKey)
    }

    /// 获取 Langfuse Secret Key
    func getLangfuseSecretKey() -> String? {
        return get(account: Keys.langfuseSecretKey)
    }

    /// 保存 Langfuse Public Key
    @discardableResult
    func saveLangfusePublicKey(_ key: String) -> Bool {
        return save(key: key, for: Keys.langfusePublicKey)
    }

    /// 保存 Langfuse Secret Key
    @discardableResult
    func saveLangfuseSecretKey(_ key: String) -> Bool {
        return save(key: key, for: Keys.langfuseSecretKey)
    }

    /// 同时保存 Langfuse Public Key 和 Secret Key
    @discardableResult
    func setLangfuseKeys(publicKey: String, secretKey: String) -> Bool {
        let publicSuccess = saveLangfusePublicKey(publicKey)
        let secretSuccess = saveLangfuseSecretKey(secretKey)
        return publicSuccess && secretSuccess
    }

    /// 检查是否已配置 Langfuse
    func hasLangfuseKeys() -> Bool {
        return getLangfusePublicKey() != nil && getLangfuseSecretKey() != nil
    }

    // MARK: - Batch Read Methods

    /// Settings 相关的所有密钥
    /// 用于批量读取，减少解密操作
    struct SettingsKeys {
        // 所有 AI 服务的 API Keys
        let openaiKey: String?
        let claudeKey: String?
        let geminiKey: String?
        let deepseekKey: String?
        let openrouterKey: String?

        // Langfuse 密钥
        let langfusePublicKey: String?
        let langfuseSecretKey: String?

        /// 获取指定服务的 API Key
        func apiKey(for serviceType: AIServiceType) -> String? {
            switch serviceType {
            case .openai: return openaiKey
            case .claude: return claudeKey
            case .gemini: return geminiKey
            case .deepseek: return deepseekKey
            case .openrouter: return openrouterKey
            case .ollama: return nil
            }
        }
    }

    /// 批量读取所有 Settings 相关的密钥
    /// 现在从 UserDefaults 读取，只需访问 Keychain 1 次（获取主密钥）
    /// - Returns: 包含所有密钥的结构体（缺失的密钥为 nil）
    func getAllSettingsKeys() -> SettingsKeys {
        print("🔑 [KeychainManager] 批量读取开始 - 从加密存储读取所有 API Keys")

        // 所有读取操作共享同一个主密钥（只访问 Keychain 1 次）
        let openaiKey = get(account: Keys.openaiAPIKey)
        print("🔑 [KeychainManager] 读取 OpenAI Key: \(openaiKey != nil ? "✅" : "❌")")

        let claudeKey = get(account: Keys.claudeAPIKey)
        print("🔑 [KeychainManager] 读取 Claude Key: \(claudeKey != nil ? "✅" : "❌")")

        let geminiKey = get(account: Keys.geminiAPIKey)
        print("🔑 [KeychainManager] 读取 Gemini Key: \(geminiKey != nil ? "✅" : "❌")")

        let deepseekKey = get(account: Keys.deepseekAPIKey)
        print("🔑 [KeychainManager] 读取 DeepSeek Key: \(deepseekKey != nil ? "✅" : "❌")")

        let openrouterKey = get(account: Keys.openrouterAPIKey)
        print("🔑 [KeychainManager] 读取 OpenRouter Key: \(openrouterKey != nil ? "✅" : "❌")")

        let publicKey = getLangfusePublicKey()
        print("🔑 [KeychainManager] 读取 Langfuse Public Key: \(publicKey != nil ? "✅" : "❌")")

        let secretKey = getLangfuseSecretKey()
        print("🔑 [KeychainManager] 读取 Langfuse Secret Key: \(secretKey != nil ? "✅" : "❌")")

        print("🔑 [KeychainManager] 批量读取完成 - 共读取 7 个密钥（Keychain 访问 1 次）")

        return SettingsKeys(
            openaiKey: openaiKey,
            claudeKey: claudeKey,
            geminiKey: geminiKey,
            deepseekKey: deepseekKey,
            openrouterKey: openrouterKey,
            langfusePublicKey: publicKey,
            langfuseSecretKey: secretKey
        )
    }

    // MARK: - Migration

    /// 迁移主密钥从旧的 service identifier 到新的
    /// 从 com.aiclipboard.masterkey 迁移到 com.senseflow.masterkey
    private func migrateMasterKeyIfNeeded() {
        // 检查是否已经有新的主密钥
        if getMasterKeyFromKeychain(service: keychainService) != nil {
            print("ℹ️ [Migration] 主密钥已存在于新位置，跳过迁移")
            return
        }

        // 尝试从旧位置读取主密钥
        guard let oldKeyData = getMasterKeyFromKeychain(service: legacyMasterKeyService) else {
            print("ℹ️ [Migration] 未发现旧主密钥，跳过迁移")
            return
        }

        print("🔄 [Migration] 发现旧主密钥，开始迁移...")

        // 保存到新位置
        if saveMasterKeyToKeychain(oldKeyData, service: keychainService) {
            print("✅ [Migration] 主密钥已迁移到 \(keychainService)")

            // 删除旧位置的密钥
            deleteFromKeychain(service: legacyMasterKeyService, account: keychainAccount)
            print("🗑️ [Migration] 旧主密钥已删除")
        } else {
            print("❌ [Migration] 主密钥迁移失败")
        }
    }

    /// 从旧的 Keychain 存储迁移到新的加密存储
    private func migrateFromLegacyKeychainIfNeeded() {
        // 检查是否已经迁移过
        let migrationKey = "keychain_migration_completed_v2"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }

        print("🔄 [Migration] 开始 API Keys 数据迁移...")

        let allKeys = [
            Keys.openaiAPIKey,
            Keys.claudeAPIKey,
            Keys.geminiAPIKey,
            Keys.deepseekAPIKey,
            Keys.openrouterAPIKey,
            Keys.langfusePublicKey,
            Keys.langfuseSecretKey
        ]

        var migratedCount = 0

        for account in allKeys {
            if let oldValue = readFromLegacyKeychain(account: account) {
                // 保存到新的加密存储
                if save(key: oldValue, for: account) {
                    migratedCount += 1
                    print("✅ [Migration] 已迁移: \(account)")

                    // 删除旧的 Keychain 条目
                    deleteFromLegacyKeychain(account: account)
                }
            }
        }

        if migratedCount > 0 {
            print("✅ [Migration] API Keys 迁移完成，共迁移 \(migratedCount) 个密钥")
        } else {
            print("ℹ️ [Migration] 无需迁移 API Keys（未发现旧数据）")
        }

        // 标记迁移完成
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// 从旧的 Keychain 读取数据
    private func readFromLegacyKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    /// 从旧的 Keychain 删除数据
    private func deleteFromLegacyKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyKeychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
