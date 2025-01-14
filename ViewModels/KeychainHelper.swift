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
final class KeychainHelper: @unchecked Sendable {
    
    // MARK: - Singleton
    static let shared = KeychainHelper()
    
    // MARK: - Private Properties

    /// A dedicated serial dispatch queue for Keychain operations to ensure thread safety.
    private let keychainQueue = DispatchQueue(label: "com.yourcompany.Mustard.KeychainQueue")
    
    /// Logger for structured and categorized logging.
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "KeychainHelper")
    
    /// Private initializer to enforce the singleton pattern.
    private init() {}
    
    // MARK: - Public API

    /// Saves a `String` value to the Keychain.
    ///
    /// - Parameters:
    ///   - value: The `String` value to save.
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Throws: `AppError` if the operation fails.

    func save(_ value: String, service: String, account: String) async throws {
        guard let data = value.data(using: .utf8) else {
            os_log("Failed to encode value to data for account: %{public}@", log: logger, type: .error, account)
            throw AppError(message: "[KeychainHelper] Encoding string to Data failed.")
        }
        try await save(data, service: service, account: account)
    }
    
    /// Saves raw `Data` to the Keychain.
    ///
    /// - Parameters:
    ///   - data: The `Data` to save.
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Throws: `AppError` if the operation fails.
    func save(_ data: Data, service: String, account: String) async throws {
        try await saveData(data, service: service, account: account)
    }
    
    /// Reads a `String` value from the Keychain.
    ///
    /// - Parameters:
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Returns: The retrieved `String` value, or `nil` if not found.
    /// - Throws: `AppError` if the operation fails.
    func read(service: String, account: String) async throws -> String? {
        guard let data = try await readData(service: service, account: account) else {
            os_log("No data found for service: %{public}@, account: %{public}@.", log: logger, type: .info, service, account)
            return nil
        }
        guard let string = String(data: data, encoding: .utf8) else {
            os_log("Failed to decode data to string for service: %{public}@, account: %{public}@.", log: logger, type: .error, service, account)
            throw AppError(message: "[KeychainHelper] Failed to decode data to String.")
        }
        
        os_log("Successfully read data for service: %{public}@, account: %{public}@.", log: logger, type: .debug, service, account)
        return string
    }
    
    /// Reads raw `Data` from the Keychain.
    ///
    /// - Parameters:
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Returns: The retrieved `Data`, or `nil` if not found.
    /// - Throws: `AppError` if the operation fails.
    func readData(service: String, account: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                let query: [String: Any] = [
                    kSecClass as String       : kSecClassGenericPassword,
                    kSecAttrService as String : service,
                    kSecAttrAccount as String : account,
                    kSecReturnData as String  : true,
                    kSecMatchLimit as String  : kSecMatchLimitOne
                ]
                
                var item: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                
                switch status {
                case errSecSuccess:
                    if let data = item as? Data {
                        os_log("Data retrieved successfully for service: %{public}@, account: %{public}@.",
                               log: self.logger, type: .debug, service, account)
                        continuation.resume(returning: data)
                    } else {
                        os_log("Data conversion error for service: %{public}@, account: %{public}@.",
                               log: self.logger, type: .error, service, account)
                        continuation.resume(throwing: AppError(message: "[KeychainHelper] Failed to convert Keychain result to Data."))
                    }
                case errSecItemNotFound:
                    os_log("No item found in Keychain for service: %{public}@, account: %{public}@.",
                           log: self.logger, type: .info, service, account)
                    continuation.resume(returning: nil)
                default:
                    // Convert OSStatus to a readable error message
                    let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                    let errorMsg = "[KeychainHelper] Keychain error (\(status)): \(message)"
                    os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                    continuation.resume(throwing: AppError(message: errorMsg))
                }
            }
        }
    }
    
    /// Deletes a value from the Keychain.
    ///
    /// - Parameters:
    ///   - service: The service identifier.
    ///   - account: The account identifier.
    /// - Throws: `AppError` if the operation fails.
    func delete(service: String, account: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                let query: [String: Any] = [
                    kSecClass as String       : kSecClassGenericPassword,
                    kSecAttrService as String : service,
                    kSecAttrAccount as String : account
                ]
                
                let status = SecItemDelete(query as CFDictionary)
                
                switch status {
                case errSecSuccess, errSecItemNotFound:
                    os_log("Successfully deleted item for service: %{public}@, account: %{public}@.",
                           log: self.logger, type: .info, service, account)
                    continuation.resume()
                default:
                    let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                    let errorMsg = "[KeychainHelper] Failed to delete item (\(status)): \(message)"
                    os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                    continuation.resume(throwing: AppError(message: errorMsg))
                }
            }
        }
    }
    
    // MARK: - Private

    /// Saves `Data` to the Keychain.
    private func saveData(_ data: Data, service: String, account: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            keychainQueue.async {
                var query: [String: Any] = [
                    kSecClass as String       : kSecClassGenericPassword,
                    kSecAttrService as String : service,
                    kSecAttrAccount as String : account
                ]
                
                // Delete any existing items with same service/account (override).
                SecItemDelete(query as CFDictionary)
                
                // Add the new item
                query[kSecValueData as String] = data
                
                let status = SecItemAdd(query as CFDictionary, nil)
                switch status {
                case errSecSuccess:
                    os_log("Data saved successfully for service: %{public}@, account: %{public}@.",
                           log: self.logger, type: .info, service, account)
                    continuation.resume()
                default:
                    let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "Unknown Keychain error."
                    let errorMsg = "[KeychainHelper] Failed to save data (\(status)): \(message)"
                    os_log("%{public}@", log: self.logger, type: .error, errorMsg)
                    continuation.resume(throwing: AppError(message: errorMsg))
                }
            }
        }
    }
}
