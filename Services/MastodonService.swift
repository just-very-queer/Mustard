//
//  MastodonService.swift
//  Mustard
//
//  Created by Your Name on 30/12/24.
//

import Foundation
import AuthenticationServices
import OSLog
import SwiftUI

/// Cached timeline with posts and timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

@MainActor
class MastodonService: NSObject, MastodonServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Singleton
    static let shared = MastodonService()

    // MARK: - Private Properties
    private var _baseURL: URL?
    private var _accessToken: String?
    private var cachedTimeline: CachedTimeline?
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "MastodonService")

    private let keychainService = "MustardKeychain"
    private let baseURLKey = "baseURL"
    private let accessTokenKey = "accessToken"
    
    // Custom JSONDecoder with .convertFromSnakeCase
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // Custom JSONEncoder with .convertToSnakeCase
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    // MARK: - MastodonServiceProtocol Properties
    var baseURL: URL? {
        get { _baseURL }
        set {
            _baseURL = newValue
            Task { await saveToKeychain(key: baseURLKey, value: newValue?.absoluteString) }
        }
    }

    var accessToken: String? {
        get { _accessToken }
        set {
            _accessToken = newValue
            Task { await saveToKeychain(key: accessTokenKey, value: newValue) }
        }
    }
    
    // MARK: - Initialization
    func ensureInitialized() async throws {
        _baseURL = await loadFromKeychain(key: baseURLKey).flatMap(URL.init)
        _accessToken = await loadFromKeychain(key: accessTokenKey)
        guard _baseURL != nil, _accessToken != nil else {
            logger.error("Service initialization failed: Missing base URL or access token.")
            throw AppError(mastodon: .missingCredentials)
        }
    }
    
    // MARK: - Authentication Methods
    func fetchCurrentUser() async throws -> User {
        guard try isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        return try await fetchData(endpoint: "/api/v1/accounts/verify_credentials", type: User.self)
    }

    func validateToken() async throws {
        _ = try await fetchData(endpoint: "/api/v1/accounts/verify_credentials", type: User.self)
    }

    func saveAccessToken(_ token: String) async throws {
        accessToken = token
    }

    func clearAccessToken() async throws {
        accessToken = nil
    }

    func retrieveAccessToken() async throws -> String? {
        return try await retrieveAccessTokenInternal()
    }

    func retrieveInstanceURL() async throws -> URL? {
        return try await retrieveInstanceURLInternal()
    }
    
    // MARK: - Timeline Methods
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        guard try isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        if useCache, let cache = cachedTimeline, Date().timeIntervalSince(cache.timestamp) < 300 {
            Task { await backgroundRefreshTimeline() }
            return cache.posts
        }
        let posts = try await fetchData(endpoint: "/api/v1/timelines/home", type: [Post].self)
        cacheTimeline(posts)
        return posts
    }

    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        guard try isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        var endpoint = "/api/v1/timelines/home"
        if page > 1, let lastID = cachedTimeline?.posts.last?.id {
            endpoint += "?max_id=\(lastID)"
        }
        return try await fetchData(endpoint: endpoint, type: [Post].self)
    }

    func clearTimelineCache() async throws {
        cachedTimeline = nil
        try? FileManager.default.removeItem(at: timelineCacheURL())
    }

    func loadTimelineFromDisk() async throws -> [Post] {
        guard let data = try? Data(contentsOf: timelineCacheURL()) else { return [] }
        return try jsonDecoder.decode([Post].self, from: data)
    }

    func saveTimelineToDisk(_ posts: [Post]) async throws {
        let data = try self.jsonEncoder.encode(posts)
        try data.write(to: timelineCacheURL())
    }

    func backgroundRefreshTimeline() async {
        do {
            _ = try await fetchTimeline(useCache: false)
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
        }
    }

    func fetchTrendingPosts() async throws -> [Post] {
        return try await fetchData(endpoint: "/api/v1/trends/statuses", type: [Post].self)
    }
    
    // MARK: - Post Actions
    func toggleLike(postID: String) async throws {
        try await postAction(for: postID, path: "/favourite")
    }

    func toggleRepost(postID: String) async throws {
        try await postAction(for: postID, path: "/reblog")
    }

    func comment(postID: String, content: String) async throws {
        guard try isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        let body: [String: Any] = ["status": content, "in_reply_to_id": postID]
        _ = try await postData(endpoint: "/api/v1/statuses", body: body, type: String.self)
    }
    
    // MARK: - OAuth
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        // Decode the response into RegisterResponse first
        let registerResponse: RegisterResponse = try await postData(
            endpoint: "/api/v1/apps",
            body: [
                "client_name": "Mustard",
                "redirect_uris": "mustard://oauth-callback",
                "scopes": "read write follow",
                "website": "https://yourapp.com"
            ],
            type: RegisterResponse.self,
            baseURLOverride: instanceURL
        )
        
        // Construct OAuthConfig using RegisterResponse and known values
        return OAuthConfig(
            clientID: registerResponse.client_id,
            clientSecret: registerResponse.client_secret,
            redirectURI: "mustard://oauth-callback",
            scope: "read write follow"
        )
    }

    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "client_secret": config.clientSecret
        ]
        let tokenResponse: TokenResponse = try await postData(
            endpoint: "/oauth/token",
            body: body,
            type: TokenResponse.self,
            baseURLOverride: instanceURL
        )
        accessToken = tokenResponse.accessToken
        logger.info("Access token acquired: \(tokenResponse.accessToken, privacy: .private)")
    }
    
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard try isAuthenticated(), let baseURL = baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = baseURL.appendingPathComponent("/api/v1/streaming/public")
        let request = try buildRequest(url: url, method: "GET")
        
        return AsyncThrowingStream { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let data = data else {
                    continuation.finish(throwing: AppError(mastodon: .invalidResponse))
                    return
                }
                do {
                    let post = try self.jsonDecoder.decode(Post.self, from: data)
                    continuation.yield(post)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Helpers
    private func fetchData<T: Decodable>(endpoint: String, type: T.Type) async throws -> T {
        let url = try endpointURL(endpoint)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func postData<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        type: T.Type,
        baseURLOverride: URL? = nil
    ) async throws -> T {
        let url = try endpointURL(endpoint, baseURLOverride: baseURLOverride)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func postAction(for postID: String, path: String) async throws {
        let url = try endpoint("/api/v1/statuses/\(postID)\(path)")
        let request = try buildRequest(url: url, method: "POST")
        _ = try await URLSession.shared.data(for: request)
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let base = baseURL else { throw AppError(mastodon: .missingCredentials) }
        return base.appendingPathComponent(path)
    }

    private func endpointURL(_ path: String, baseURLOverride: URL? = nil) throws -> URL {
        guard let base = baseURLOverride ?? baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }
        return base.appendingPathComponent(path)
    }

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let token = accessToken else { throw AppError(mastodon: .missingCredentials) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            logger.error("Invalid response type received.")
            throw AppError(mastodon: .invalidResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            logger.error("Server returned status code \(http.statusCode).")
            throw AppError(mastodon: .serverError(status: http.statusCode))
        }
    }

    private func isAuthenticated() throws -> Bool {
        guard let base = baseURL, let token = accessToken, !base.absoluteString.isEmpty, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        return true
    }

    private func cacheTimeline(_ posts: [Post]) {
        cachedTimeline = CachedTimeline(posts: posts, timestamp: Date())
        Task { try? await saveTimelineToDisk(posts) }
    }

    private func timelineCacheURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("timelineCache.json")
    }

    func saveToKeychain(key: String, value: String?) async {
        guard let value = value else { return }
        do {
            try await KeychainHelper.shared.save(value, service: keychainService, account: key)
            logger.debug("Saved \(key) to Keychain.")
        } catch {
            logger.error("Failed to save \(key) to Keychain: \(error.localizedDescription)")
        }
    }

    func loadFromKeychain(key: String) async -> String? {
        do {
            let value = try await KeychainHelper.shared.read(service: keychainService, account: key)
            logger.debug("Loaded \(key) from Keychain: \(value ?? "nil")")
            return value
        } catch {
            logger.error("Failed to load \(key) from Keychain: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func retrieveAccessTokenInternal() async throws -> String? {
           return try await KeychainHelper.shared.read(service: keychainService, account: accessTokenKey)
    }

    private func retrieveInstanceURLInternal() async throws -> URL? {
           if let baseURLString = try await KeychainHelper.shared.read(service: keychainService, account: baseURLKey),
              let url = URL(string: baseURLString) {
               return url
           }
           return nil
       }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Notification Utility
extension Notification.Name {
    static let didReceiveOAuthCallback = Notification.Name("didReceiveOAuthCallback")
    static let didAuthenticate = Notification.Name("didAuthenticate")
    static let authenticationFailed = Notification.Name("authenticationFailed")
    static let didSelectAccount = Notification.Name("didSelectAccount")
}
