//
//  NetworkService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import AuthenticationServices
import OSLog
import SwiftUI
import CoreLocation

class NetworkService {
    static let shared = NetworkService()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "NetworkService")
    private var rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0)
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let keychainService = "MustardKeychain" // Defining keychain service name
    
    private init() {
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let iso8601FormatterWithFractionalSeconds = ISO8601DateFormatter()
            iso8601FormatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601FormatterWithFractionalSeconds.date(from: dateString) {
                return date
            }
            
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
        jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    // Fetch Data with Generic Type T
    func fetchData<T: Decodable>(url: URL, method: String, type: T.Type) async throws -> T {
        guard rateLimiter.tryConsume() else {
            throw AppError(type: .mastodon(.rateLimitExceeded))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Perform async network request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                logger.error("Invalid or server error response.")
                throw AppError(mastodon: .invalidResponse)
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw JSON response: \(jsonString)")
            }
            
            return try jsonDecoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch {
            throw AppError(type: .network(.requestFailed(underlyingError: error)), underlyingError: error)
        }
    }
    
    // Post Data with Generic Type T
    func postData<T: Decodable>(
        endpoint: String,
        body: [String: String],
        type: T.Type,
        baseURLOverride: URL? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }
        
        let url = try await endpointURL(endpoint, baseURLOverride: baseURLOverride)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try buildBody(body: body, contentType: contentType)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try jsonDecoder.decode(T.self, from: data)
    }
    
    // Post action (like/repost)
    func postAction(for postID: String, path: String, baseURLOverride: URL? = nil) async throws {
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }
        
        // Use the instance URL from the server parameter if available
        guard let instanceURLString = try? await KeychainHelper.shared.read(service: keychainService, account: "baseURL"),
              let instanceURL = URL(string: instanceURLString) else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        let url = try await endpointURL(path, baseURLOverride: instanceURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // Construct endpoint URL, fallback to the base URL from Keychain if needed
    func endpointURL(_ path: String, baseURLOverride: URL? = nil) async throws -> URL {
        // Use the instance URL from the server parameter if available
        if let baseURLOverride = baseURLOverride {
            return baseURLOverride.appendingPathComponent(path)
        }
        
        // Fallback to the base URL from Keychain
        guard let base = URL(string: (try? await KeychainHelper.shared.read(service: keychainService, account: "baseURL")) ?? "") else {
            throw AppError(mastodon: .missingCredentials)
        }
        return base.appendingPathComponent(path)
    }
    
    // Build a URLRequest
    func buildRequest(url: URL, method: String, accessToken: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    // Validate the response status code
    func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.error("Invalid or server error response.")
            throw AppError(mastodon: .invalidResponse)
        }
    }
    
    // Registers the app with the specified Mastodon instance to get OAuth client credentials.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let body = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow",
            "website": "https://example.com" // Replace with your app's website
        ]
        let requestURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AppError(mastodon: .encodingError, underlyingError: error)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError(mastodon: .invalidResponse)
        }
        
        let registerResponse: RegisterResponse
        do {
            registerResponse = try jsonDecoder.decode(RegisterResponse.self, from: data)
        } catch {
            throw AppError(mastodon: .decodingError, underlyingError: error)
        }
        
        return OAuthConfig(
            clientId: registerResponse.clientId,
            clientSecret: registerResponse.clientSecret,
            redirectUri: registerResponse.redirectUri ?? "",
            scope: "read write follow"
        )
    }
    
    // Exchange the authorization code for an access token
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri": config.redirectUri,
            "scope": config.scope
        ]
        let requestURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = body.map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(key)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError(mastodon: .failedToExchangeCode)
        }
        
        let tokenResponse = try jsonDecoder.decode(TokenResponse.self, from: data)
        try await KeychainHelper.shared.save(tokenResponse.accessToken, service: keychainService, account: "accessToken")
    }
    
    // Fetch the current user from the Mastodon instance
    func fetchCurrentUser(instanceURL: URL? = nil) async throws -> User {
        let userFetchURL: URL
        if let instanceURL = instanceURL {
            userFetchURL = instanceURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        } else {
            guard let baseURLString = try? await KeychainHelper.shared.read(service: keychainService, account: "baseURL"),
                  let baseURL = URL(string: baseURLString) else {
                throw AppError(mastodon: .missingCredentials)
            }
            userFetchURL = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        }
        
        let user = try await fetchData(url: userFetchURL, method: "GET", type: User.self)
        return user
    }
    
    // Helper for building the HTTP body for POST requests
    private func buildBody(body: [String: String], contentType: String) throws -> Data? {
        switch contentType {
        case "application/json":
            return try JSONSerialization.data(withJSONObject: body)
        case "application/x-www-form-urlencoded":
            return body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)
        default:
            throw AppError(message: "Unsupported content type: \(contentType)")
        }
    }
    
    // Log Decoding Errors
    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription as String)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue)' not found, Context: \(context.debugDescription as String)")
        case .valueNotFound(let value, let context):
            logger.error("Value of type '\(String(describing: value))' not found, Context: \(context.debugDescription as String)")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(String(describing: type))' mismatch, Context: \(context.debugDescription as String)")
        @unknown default:
            logger.error("Unknown decoding error")
        }
    }
}
