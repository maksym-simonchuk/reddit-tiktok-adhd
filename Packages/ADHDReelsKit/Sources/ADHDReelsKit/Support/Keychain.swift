import Foundation
import Security

/// Secrets live in the keychain, not in the settings blob: UserDefaults travels with
/// backups in plain text, and an API key must not.
enum Keychain {

    private static let service = "com.local.adhdreels"

    static func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    /// `nil` or an empty string deletes the entry — a blank key is not a credential.
    /// Returns whether the keychain actually holds the requested state afterwards.
    @discardableResult
    static func set(_ value: String?, for account: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let deleted = SecItemDelete(base as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else { return false }

        guard let value, !value.isEmpty else { return true }

        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
