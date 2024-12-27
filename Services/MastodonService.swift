//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Service responsible for interacting with the Mastodon API.
class MastodonService: MastodonServiceProtocol {
    
    /// The base URL of the Mastodon instance.
    var baseURL: URL?
    
    /// The access token for authenticated requests.
    var accessToken: String? {
        get {
            guard let baseURL = baseURL else {
                print("accessToken getter: baseURL not set.")
                return nil
            }
            let service = "Mustard-\(baseURL.host ?? "unknown")"
            do {
                let token = try KeychainHelper.shared.read(service: service, account: "accessToken")
                print("accessToken getter: Retrieved token: \(token ?? "nil") for service: \(service)")
                return token
            } catch {
                print("accessToken getter: Failed to retrieve access token: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let baseURL = baseURL else {
                print("accessToken setter: baseURL not set.")
                return
            }
            let service = "Mustard-\(baseURL.host ?? "unknown")"
            if let token = newValue {
                print("accessToken setter: Saving token: \(token) for service: \(service)")
                do {
                    try KeychainHelper.shared.save(token, service: service, account: "accessToken")
                    print("accessToken setter: Token saved successfully.")
                } catch {
                    print("accessToken setter: Failed to save access token: \(error.localizedDescription)")
                }
            } else {
                print("accessToken setter: Deleting token for service: \(service)")
                do {
                    try KeychainHelper.shared.delete(service: service, account: "accessToken")
                    print("accessToken setter: Token deleted successfully.")
                } catch {
                    print("accessToken setter: Failed to delete access token: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Networking Methods
    
    /// Fetches the authenticated user's home timeline.
    func fetchTimeline() async throws -> [Post] {
        guard let baseURL = baseURL else {
            print("fetchTimeline: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        
        let timelineURL = baseURL.appendingPathComponent("/api/v1/timelines/home")
        print("fetchTimeline: Fetching timeline from URL: \(timelineURL)")
        var request = URLRequest(url: timelineURL)
        request.httpMethod = "GET"
        
        guard let token = accessToken else {
            print("fetchTimeline: Access token not available.")
            throw AppError(message: "Access token not available.")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let postData = try decoder.decode([PostData].self, from: data)
        print("fetchTimeline: Fetched \(postData.count) posts from timeline.")
        return postData.map { $0.toPost() }
    }
    
    /// Saves the access token securely in the keychain.
    func saveAccessToken(_ token: String) throws {
        guard let baseURL = baseURL else {
            print("saveAccessToken: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")"
        print("saveAccessToken: Saving access token for service: \(service)")
        do {
            try KeychainHelper.shared.save(token, service: service, account: "accessToken")
            print("saveAccessToken: Access token saved successfully.")
        } catch {
            print("saveAccessToken: Failed to save access token: \(error.localizedDescription)")
            throw AppError(message: "Failed to save access token.")
        }
    }
    
    /// Clears the access token from the keychain.
    func clearAccessToken() throws {
        guard let baseURL = baseURL else {
            print("clearAccessToken: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")"
        print("clearAccessToken: Deleting access token for service: \(service)")
        do {
            try KeychainHelper.shared.delete(service: service, account: "accessToken")
            print("clearAccessToken: Access token deleted successfully.")
        } catch {
            print("clearAccessToken: Failed to delete access token: \(error.localizedDescription)")
            throw AppError(message: "Failed to delete access token.")
        }
    }
    
    /// Toggles the like (favorite) status of a post.
    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/favourite")
    }
    
    /// Toggles the repost (reblog) status of a post.
    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/reblog")
    }
    
    /// Comments on a specific post.
    func comment(postID: String, content: String) async throws {
        guard let baseURL = baseURL else {
            print("comment: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        guard let accessToken = accessToken else {
            print("comment: Access token not available.")
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
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("comment: Failed to serialize JSON body: \(error.localizedDescription)")
            throw AppError(message: "Failed to create comment.")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("comment: Comment posted successfully.")
    }
    
    // MARK: - Private Helper Methods
    
    /// Toggles an action (like/repost) for a specific post.
    private func toggleAction(for postID: String, endpoint: String) async throws {
        guard let baseURL = baseURL else {
            print("toggleAction: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        guard let accessToken = accessToken else {
            print("toggleAction: Access token not available.")
            throw AppError(message: "Access token not available.")
        }
        
        let actionURL = baseURL.appendingPathComponent("/api/v1/statuses/\(postID)\(endpoint)")
        print("toggleAction: Toggling action at URL: \(actionURL)")
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("toggleAction: Action toggled successfully at URL: \(actionURL)")
    }
    
    /// Validates the HTTP response, throwing an error for unsuccessful status codes.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("validateResponse: Invalid response.")
            throw AppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            print("validateResponse: HTTP Error: \(httpResponse.statusCode)")
            throw AppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
        print("validateResponse: Response validated with status code: \(httpResponse.statusCode)")
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    /// Fetches the authenticated user's account details.
    func fetchAccounts() async throws -> [Account] {
        guard let baseURL = baseURL else {
            print("fetchAccounts: baseURL not set.")
            throw AppError(message: "Base URL not set.")
        }
        guard let token = accessToken else {
            print("fetchAccounts: Access token not available.")
            throw AppError(message: "Access token not available.")
        }
        
        let accountsURL = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        var request = URLRequest(url: accountsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("fetchAccounts: Fetching account details from URL: \(accountsURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let accountData = try decoder.decode(AccountData.self, from: data)
        print("fetchAccounts: Retrieved account details for username: \(accountData.username)")
        return [accountData.toAccount(baseURL: baseURL)]
    }
    
    /// Registers a new account on the specified Mastodon instance.
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account {
        let registerURL = instanceURL.appendingPathComponent("/api/v1/accounts")
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("registerAccount: Failed to serialize JSON body: \(error.localizedDescription)")
            throw AppError(message: "Failed to create account.")
        }
        
        print("registerAccount: Registering account at URL: \(registerURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let accountData = try decoder.decode(AccountData.self, from: data)
        print("registerAccount: Account registered successfully for username: \(accountData.username)")
        return accountData.toAccount(baseURL: instanceURL)
    }
    
    /// Authenticates a user and retrieves an access token.
    func authenticate(username: String, password: String, instanceURL: URL) async throws -> String {
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let body: [String: Any] = [
            "grant_type": "password",
            "username": username,
            "password": password,
            "client_id": "YOUR_CLIENT_ID",        // Replace with actual client ID
            "client_secret": "YOUR_CLIENT_SECRET",// Replace with actual client secret
            "scope": "read write follow"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("authenticate: Failed to serialize JSON body: \(error.localizedDescription)")
            throw AppError(message: "Failed to authenticate.")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("authenticate: Authenticating user at URL: \(tokenURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        let tokenData = try decoder.decode(TokenResponse.self, from: data)
        print("authenticate: Authentication successful. Access token: \(tokenData.accessToken)")
        return tokenData.accessToken
    }
    
    /// Retrieves the stored access token.
    func retrieveAccessToken() throws -> String? {
        guard let baseURL = baseURL else {
            print("retrieveAccessToken: baseURL not set.")
            return nil
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")"
        do {
            let token = try KeychainHelper.shared.read(service: service, account: "accessToken")
            print("retrieveAccessToken: Retrieved access token: \(token ?? "nil") for service: \(service)")
            return token
        } catch {
            print("retrieveAccessToken: Failed to retrieve access token: \(error.localizedDescription)")
            return nil
        }
    }

    /// Retrieves the current instance URL.
    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }
    
    // MARK: - Supporting Structures
    
    /// Represents the response received after authenticating.
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
    
    /// Represents the account data retrieved from Mastodon.
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
        
        /// Converts AccountData to your local Account model.
        /// - Parameter baseURL: The base URL of the Mastodon instance.
        /// - Returns: An instance of Account.
        func toAccount(baseURL: URL?) -> Account {
            return Account(
                id: id,
                username: username,
                displayName: displayName,
                avatar: URL(string: avatar) ?? URL(string: "https://example.com/default_avatar.png")!,
                acct: acct,
                instanceURL: URL(string: url) ?? baseURL ?? URL(string: "https://mastodon.social")!,
                accessToken: "" // Access token should be managed separately
            )
        }
    }
}

