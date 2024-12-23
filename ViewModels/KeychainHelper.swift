//
//  KeychainHelper.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    func save(_ data: String, service: String, account: String) {
        if let data = data.data(using: .utf8) {
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecValueData: data
            ] as CFDictionary

            SecItemDelete(query) // Delete old item if exists
            let status = SecItemAdd(query, nil)
            if status != errSecSuccess {
                print("Error saving to Keychain: \(status)")
            }
        }
    }

    func read(service: String, account: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    func delete(service: String, account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        SecItemDelete(query)
    }
}

