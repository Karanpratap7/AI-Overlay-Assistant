import Foundation
import Security

/// Secure credential storage using macOS Keychain.
/// All API keys are stored exclusively here — never in .env files or UserDefaults.
final class KeychainService {

    static let shared = KeychainService()

    private let serviceName = "com.aioverlay.assistant"

    // MARK: - Key identifiers

    enum KeyIdentifier: String, CaseIterable {
        case openAIKey = "openai_api_key"
        case anthropicKey = "anthropic_api_key"
        case geminiKey = "gemini_api_key"
        case googleVisionKey = "google_vision_api_key"
        case whisperAPIKey = "whisper_api_key"
    }

    // MARK: - Save

    @discardableResult
    func save(key: KeyIdentifier, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain save failed for \(key.rawValue): \(status)")
        }
        return status == errSecSuccess
    }

    // MARK: - Retrieve

    func retrieve(key: KeyIdentifier) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    // MARK: - Delete

    @discardableResult
    func delete(key: KeyIdentifier) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Check

    func hasKey(_ key: KeyIdentifier) -> Bool {
        return retrieve(key: key) != nil
    }

    /// Returns a dictionary of which keys are configured.
    func configuredKeys() -> [KeyIdentifier: Bool] {
        var result: [KeyIdentifier: Bool] = [:]
        for key in KeyIdentifier.allCases {
            result[key] = hasKey(key)
        }
        return result
    }

    /// Deletes all stored keys.
    func clearAll() {
        for key in KeyIdentifier.allCases {
            delete(key: key)
        }
    }
}
