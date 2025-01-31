//
//  KeychainHelper.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import Security
import OSLog

/// A helper class for interacting with the iOS Keychain, providing secure storage for sensitive data.
final class KeychainHelper: @unchecked Sendable { // Marking explicitly to avoid concurrency warnings
     
    // MARK: - Singleton
    static let shared = KeychainHelper()

    // MARK: - Private Properties
    /// A dedicated serial dispatch queue for Keychain operations to ensure thread safety.
    private let keychainQueue = DispatchQueue(label: "com.yourcompany.Mustard.KeychainQueue", attributes: .concurrent)
    
    /// Logger for structured and categorized logging.
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "KeychainHelper")

    /// Private initializer to enforce the singleton pattern.
    private init() {}

    // MARK: - Public API
    
    /// Saves a `String` value to the Keychain.
    func save(_ value: String, service: String, account: String) async throws {
        guard let data = value.data(using: .utf8) else {
            os_log("Failed to encode value for account: %{public}@", log: logger, type: .error, account)
            throw AppError(message: "Encoding string to Data failed.")
        }
        try await save(data, service: service, account: account)
    }

    /// Saves raw `Data` to the Keychain.
    func save(_ data: Data, service: String, account: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                Task.detached { [weak self] in
                    guard let self = self else { return }

                    var query: [String: Any] = [
                        kSecClass as String       : kSecClassGenericPassword,
                        kSecAttrService as String : service,
                        kSecAttrAccount as String : account
                    ]
                    
                    // Delete any existing items with the same service/account
                    SecItemDelete(query as CFDictionary)
                    
                    // Add the new item
                    query[kSecValueData as String] = data
                    
                    let status = SecItemAdd(query as CFDictionary, nil)
                    
                    if status == errSecSuccess {
                        os_log("Data saved successfully for service: %{public}@, account: %{public}@", log: self.logger, type: .info, service, account)
                        continuation.resume()
                    } else {
                        let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                        let errorMsg = "[KeychainHelper] Failed to save data: \(status): \(message)"
                        os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                        continuation.resume(throwing: AppError(message: errorMsg))
                    }
                }
            }
        }
    }

    /// Reads a `String` value from the Keychain.
    func read(service: String, account: String) async throws -> String? {
        guard let data = try await readData(service: service, account: account) else {
            os_log("No data found for service: %{public}@, account: %{public}@", log: logger, type: .info, service, account)
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            os_log("Failed to decode data to string for service: %{public}@, account: %{public}@", log: logger, type: .error, service, account)
            throw AppError(message: "[KeychainHelper] Failed to decode data to String.")
        }
        
        return string
    }

    /// Reads raw `Data` from the Keychain.
    func readData(service: String, account: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                Task.detached { [weak self] in
                    guard let self = self else { return }

                    let query: [String: Any] = [
                        kSecClass as String       : kSecClassGenericPassword,
                        kSecAttrService as String : service,
                        kSecAttrAccount as String : account,
                        kSecReturnData as String  : true,
                        kSecMatchLimit as String  : kSecMatchLimitOne
                    ]
                    
                    var item: AnyObject?
                    let status = SecItemCopyMatching(query as CFDictionary, &item)
                    
                    if status == errSecSuccess, let data = item as? Data {
                        continuation.resume(returning: data)
                    } else if status == errSecItemNotFound {
                        os_log("No item found in Keychain for service: %{public}@, account: %{public}@", log: self.logger, type: .info, service, account)
                        continuation.resume(returning: nil)
                    } else {
                        let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                        let errorMsg = "[KeychainHelper] Keychain error (\(status)): \(message)"
                        os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                        continuation.resume(throwing: AppError(message: errorMsg))
                    }
                }
            }
        }
    }

    /// Deletes a value from the Keychain.
    func delete(service: String, account: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                Task.detached { [weak self] in
                    guard let self = self else { return }

                    let query: [String: Any] = [
                        kSecClass as String       : kSecClassGenericPassword,
                        kSecAttrService as String : service,
                        kSecAttrAccount as String : account
                    ]
                    
                    let status = SecItemDelete(query as CFDictionary)
                    
                    if status == errSecSuccess || status == errSecItemNotFound {
                        os_log("Successfully deleted item for service: %{public}@, account: %{public}@", log: self.logger, type: .info, service, account)
                        continuation.resume()
                    } else {
                        let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                        let errorMsg = "[KeychainHelper] Failed to delete item (\(status)): \(message)"
                        os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                        continuation.resume(throwing: AppError(message: errorMsg))
                    }
                }
            }
        }
    }
}
