import Foundation
import Security

/// Thin Keychain wrapper used for refresh tokens and other secrets that should
/// survive uninstall-via-backup but stay encrypted at rest.
public struct KeychainStore: Sendable {
    public let service: String
    public let accessGroup: String?

    public init(service: String = "app.lumen.keychain", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    @discardableResult
    public func set(_ data: Data, forKey key: String) -> Bool {
        var query = baseQuery(key: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public func get(_ key: String) -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    public func delete(_ key: String) -> Bool {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(key: String) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }
}
