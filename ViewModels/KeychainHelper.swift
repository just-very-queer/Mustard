//
//  KeychainHelper.swift
//  Mustard
//
//  Created by Your Name on [Date].
//

import Foundation
import Security

/// A simple helper class for reading/writing data to the iOS Keychain.
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    /// Saves data (String) to the Keychain.
    /// - Parameters:
    ///   - data: The string data to save.
    ///   - service: A unique service identifier, e.g., "Mustard-mastodon.social"
    ///   - account: The account identifier, e.g. "accessToken"
    func save(_ data: String, service: String, account: String) throws {
        guard let valueData = data.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        let query: [String: Any] = [
            kSecClass as String            : kSecClassGenericPassword,
            kSecAttrService as String      : service,
            kSecAttrAccount as String      : account
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        var newItem = query
        newItem[kSecValueData as String] = valueData
        
        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Reads data (String) from the Keychain.
    /// - Parameters:
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Returns: The retrieved string, if available.
    func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String            : kSecClassGenericPassword,
            kSecAttrService as String      : service,
            kSecAttrAccount as String      : account,
            kSecReturnData as String       : true,
            kSecMatchLimit as String       : kSecMatchLimitOne
        ]
        
        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        
        switch status {
        case errSecSuccess:
            if let data = dataRef as? Data,
               let stringValue = String(data: data, encoding: .utf8) {
                return stringValue
            } else {
                throw KeychainError.dataConversionError
            }
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Deletes data from the Keychain.
    /// - Parameters:
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String            : kSecClassGenericPassword,
            kSecAttrService as String      : service,
            kSecAttrAccount as String      : account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Keychain Errors
    
    enum KeychainError: Error, LocalizedError {
        case encodingError
        case dataConversionError
        case unhandledError(status: OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .encodingError:
                return "[KeychainHelper] Failed to encode data."
            case .dataConversionError:
                return "[KeychainHelper] Failed to decode data."
            case .unhandledError(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error."
                return "[KeychainHelper] \(message) (OSStatus: \(status))"
            }
        }
    }
}

