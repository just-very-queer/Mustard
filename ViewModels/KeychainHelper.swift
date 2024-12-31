//
//  KeychainHelper.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func save(_ data: String, service: String, account: String) throws {
        guard let data = data.data(using: .utf8) else { throw KeychainError.encodingError }
        
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
            kSecValueData as String   : data
        ]
        
        SecItemDelete(query as CFDictionary) // Delete any existing items
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
    }
    
    func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account,
            kSecReturnData as String  : true,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]
        
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        guard let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        return string
    }
    
    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrService as String : service,
            kSecAttrAccount as String : account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandledError(status: status) }
    }
    
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

