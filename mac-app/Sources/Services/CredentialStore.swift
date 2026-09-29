import Foundation

/// Plain-file credential storage at
/// ~/Library/Application Support/AIOverlayAssistant/credentials.json.
/// Kept intentionally keychain-free so the app never triggers keychain
/// permission prompts. File is readable/writable only by the current user.
final class CredentialStore {

    static let shared = CredentialStore()

    // MARK: - Key identifiers

    enum KeyIdentifier: String, CaseIterable {
        case openAIKey = "openai_api_key"
        case anthropicKey = "anthropic_api_key"
        case geminiKey = "gemini_api_key"
        case whisperAPIKey = "whisper_api_key"
    }

    // MARK: - Storage location

    private let fileManager = FileManager.default
    private var storeDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AIOverlayAssistant", isDirectory: true)
    }
    private var fileURL: URL {
        storeDirectory.appendingPathComponent("credentials.json")
    }

    // MARK: - Core IO

    private func readAll() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    @discardableResult
    private func writeAll(_ dict: [String: String]) -> Bool {
        do {
            try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: storeDirectory.path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(dict)
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            print("❌ CredentialStore write failed: \(error)")
            return false
        }
    }

    // MARK: - Save

    @discardableResult
    func save(key: KeyIdentifier, value: String) -> Bool {
        var dict = readAll()
        dict[key.rawValue] = value
        return writeAll(dict)
    }

    // MARK: - Retrieve

    func retrieve(key: KeyIdentifier) -> String? {
        return readAll()[key.rawValue]
    }

    // MARK: - Delete

    @discardableResult
    func delete(key: KeyIdentifier) -> Bool {
        var dict = readAll()
        guard dict.removeValue(forKey: key.rawValue) != nil else { return true }
        return writeAll(dict)
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