import Foundation
import Security

struct TwitchCredentials: Codable, Equatable {
    let clientId: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String
    let login: String
    let scopes: [String]
}

protocol CredentialStoring {
    func load() throws -> TwitchCredentials?
    func save(_ credentials: TwitchCredentials) throws
    func clear() throws
}

/// One Keychain record makes refresh-token rotation atomic. Credentials never
/// enter UserDefaults, URLs, player JavaScript, logs or iCloud Keychain.
struct KeychainCredentialStore: CredentialStoring {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.saphid.duotwitch.oauth",
         kSecAttrAccount as String: "twitch-session"]
    }

    func load() throws -> TwitchCredentials? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let result = SecItemCopyMatching(q as CFDictionary, &item)
        if result == errSecItemNotFound { return nil }
        guard result == errSecSuccess, let data = item as? Data,
              let value = try? JSONDecoder().decode(TwitchCredentials.self, from: data) else { throw TwitchError.keychain }
        return value
    }

    func save(_ credentials: TwitchCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let fields: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(query as CFDictionary, fields as CFDictionary)
        if updated == errSecItemNotFound {
            var added = query
            fields.forEach { added[$0.key] = $0.value }
            guard SecItemAdd(added as CFDictionary, nil) == errSecSuccess else { throw TwitchError.keychain }
        } else if updated != errSecSuccess { throw TwitchError.keychain }
    }

    func clear() throws {
        let result = SecItemDelete(query as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw TwitchError.keychain }
    }
}
