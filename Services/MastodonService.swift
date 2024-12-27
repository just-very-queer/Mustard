//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Service responsible for interacting with the Mastodon API.
class MastodonService: MastodonServiceProtocol {
    var baseURL: URL?
    
    var accessToken: String? {
        get {
            guard let baseURL = baseURL else { return nil }
            let service = "Mustard-\(baseURL.host ?? "")"
            return try? KeychainHelper.shared.read(service: service, account: "accessToken")
        }
        set {
            guard let baseURL = baseURL else { return }
            let service = "Mustard-\(baseURL.host ?? "")"
            if let token = newValue {
                try? KeychainHelper.shared.save(token, service: service, account: "accessToken")
            } else {
                try? KeychainHelper.shared.delete(service: service, account: "accessToken")
            }
        }
    }
    
    // MARK: - Networking Methods
    
    func fetchTimeline() async throws -> [Post] {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        
        let timelineURL = baseURL.appendingPathComponent("/api/v1/timelines/home")
        var request = URLRequest(url: timelineURL)
        request.httpMethod = "GET"
        guard let token = accessToken else {
            throw AppError(message: "Access token not available.")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let postData = try decoder.decode([PostData].self, from: data)
        return postData.map { $0.toPost() }
    }
    
    func saveAccessToken(_ token: String) throws {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        let service = "Mustard-\(baseURL.host ?? "")"
        try KeychainHelper.shared.save(token, service: service, account: "accessToken")
    }
    
    func clearAccessToken() throws {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        let service = "Mustard-\(baseURL.host ?? "")"
        try KeychainHelper.shared.delete(service: service, account: "accessToken")
    }
    
    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/favourite")
    }
    
    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/reblog")
    }
    
    func comment(postID: String, content: String) async throws {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        guard let accessToken = accessToken else {
            throw AppError(message: "Access token not available.")
        }
        
        let commentURL = baseURL.appendingPathComponent("/api/v1/statuses")
        var request = URLRequest(url: commentURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "status": content,
            "in_reply_to_id": postID
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }
    
    // MARK: - Private Helper Methods
    
    private func toggleAction(for postID: String, endpoint: String) async throws {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        guard let accessToken = accessToken else {
            throw AppError(message: "Access token not available.")
        }
        
        let actionURL = baseURL.appendingPathComponent("/api/v1/statuses/\(postID)\(endpoint)")
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    func fetchAccounts() async throws -> [Account] {
        guard let baseURL = baseURL else {
            throw AppError(message: "Base URL not set.")
        }
        guard let token = accessToken else {
            throw AppError(message: "Access token not available.")
        }
        
        let accountsURL = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        var request = URLRequest(url: accountsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let accountData = try decoder.decode(AccountData.self, from: data)
        return [accountData.toAccount(baseURL: baseURL)]
    }
    
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account {
        let registerURL = instanceURL.appendingPathComponent("/api/v1/accounts")
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let accountData = try decoder.decode(AccountData.self, from: data)
        return accountData.toAccount(baseURL: instanceURL)
    }
    
    func authenticate(username: String, password: String, instanceURL: URL) async throws -> String {
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "grant_type": "password",
            "username": username,
            "password": password,
            "client_id": "YOUR_CLIENT_ID",
            "client_secret": "YOUR_CLIENT_SECRET",
            "scope": "read write follow"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        let tokenData = try decoder.decode(TokenResponse.self, from: data)
        return tokenData.accessToken
    }
    
    func retrieveAccessToken() throws -> String? {
        return accessToken
    }
    
    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }
    
    // MARK: - Supporting Structures
    
    struct TokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let scope: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case scope
        }
    }
    
    struct AccountData: Decodable {
        let id: String
        let username: String
        let displayName: String
        let avatar: String
        let acct: String
        let url: String
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case displayName = "display_name"
            case avatar
            case acct
            case url
            case createdAt = "created_at"
        }
        
        func toAccount(baseURL: URL?) -> Account {
            return Account(
                id: id,
                username: username,
                displayName: displayName,
                avatar: URL(string: avatar) ?? URL(string: "https://example.com/default_avatar.png")!,
                acct: acct,
                instanceURL: URL(string: url) ?? baseURL ?? URL(string: "https://mastodon.social")!,
                accessToken: "defaultAccessToken"
            )
        }
    }
    
    struct AppError: LocalizedError {
        var message: String
        
        var errorDescription: String? {
            return message
        }
    }
}

