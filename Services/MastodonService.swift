//
//  MastodonService.swift
//  Mustard
//
//  Created by Your Name on 30/12/24.
//

import Foundation
import AuthenticationServices
import SwiftUI
import CryptoKit
import OSLog

/// A simple struct for caching timeline data with timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

@MainActor
class MastodonService: NSObject, MastodonServiceProtocol, ASWebAuthenticationPresentationContextProviding {

    // MARK: - Singleton
    static let shared = MastodonService()

    // MARK: - Private Keychain Identifiers
    private let baseURLKeychainService    = "Mustard-baseURL"
    private let baseURLKeychainAccount    = "baseURL"
    private let accessTokenKeychainAccount = "accessToken"

    // MARK: - Private Properties
    private var _baseURL: URL?
    private var _accessToken: String?
    
    private var cachedTimeline: CachedTimeline?
    private var cacheFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("mustard_timeline.json")
    }

    // If needed for PKCE, keep these. Otherwise remove them.
    private var codeVerifier: String?
    private var state: String?
    private var isAuthenticatingSession = false

    // Logger for debugging
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "MastodonService")
    
    // MARK: - MastodonServiceProtocol

    /// The Mastodon instance URL (e.g., "https://mastodon.social").
    var baseURL: URL? {
        get { _baseURL }
        set {
            _baseURL = newValue
            Task { await storeBaseURL(newValue) }
        }
    }

    /// The current OAuth access token, if available.
    var accessToken: String? {
        get { _accessToken }
        set {
            _accessToken = newValue
            Task { await storeAccessToken(newValue) }
        }
    }

    // MARK: - Initialization
       func ensureInitialized() async {
           if _baseURL == nil || _accessToken == nil {
               await initializeService()
           }
       }

       /// Initializes the service by loading the base URL and access token.
       private func initializeService() async {
           do {
               _baseURL = await loadBaseURL()
               _accessToken = await loadAccessToken()

               if _baseURL == nil || _accessToken == nil {
                   os_log("Service initialization: Missing base URL or access token.", log: logger, type: .error)
               } else {
                   os_log("Service initialized with base URL: %{public}@ and access token.", log: logger, type: .info, _baseURL?.absoluteString ?? "nil")
               }
           }
       }

    // MARK: - Timeline Methods

    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        // 1) Ensure we have credentials
        guard try isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }

        // 2) If asked, return cached data if fresh
        if useCache, let cache = cachedTimeline,
           Date().timeIntervalSince(cache.timestamp) < 300 {
            Task { await backgroundRefreshTimeline() }
            return cache.posts
        }

        // 3) Build request
        let timelineURL = try timelineEndpoint("home")
        let request     = try buildRequest(url: timelineURL, method: "GET")

        // 4) Perform network call
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        // 5) Parse
        let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
        let posts = postDataArray.map { $0.toPost(instanceURL: baseURL!) }

        // 6) Cache & save
        cachedTimeline = CachedTimeline(posts: posts, timestamp: Date())
        try await saveTimelineToDisk(posts)
        return posts
    }

    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        guard try isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }

        let timelineURL = try timelineEndpoint("home")
        var comps       = URLComponents(url: timelineURL, resolvingAgainstBaseURL: false)!
        var queryItems  = [URLQueryItem(name: "limit", value: "20")]

        // If user wants page>1, we can use "max_id" to fetch older posts
        if page > 1, let lastPostID = cachedTimeline?.posts.last?.id {
            queryItems.append(URLQueryItem(name: "max_id", value: lastPostID))
        }
        comps.queryItems = queryItems

        guard let finalURL = comps.url else {
            throw AppError(mastodon: .encodingError)
        }

        let request = try buildRequest(url: finalURL, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
        return postDataArray.map { $0.toPost(instanceURL: baseURL!) }
    }

    func clearTimelineCache() async throws {
        cachedTimeline = nil
        guard let fileURL = cacheFileURL else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw AppError(mastodon: .networkError(underlying: error))
        }
    }

    func loadTimelineFromDisk() async throws -> [Post] {
        guard let fileURL = cacheFileURL else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Post].self, from: data)
        } catch {
            throw AppError(mastodon: .networkError(underlying: error))
        }
    }

    func saveTimelineToDisk(_ posts: [Post]) async throws {
        guard let fileURL = cacheFileURL else { return }
        do {
            let data = try JSONEncoder().encode(posts)
            try data.write(to: fileURL)
        } catch {
            throw AppError(mastodon: .encodingError)
        }
    }

    func backgroundRefreshTimeline() async {
        // Optional background refresh logic
        do {
            _ = try await fetchTimeline(useCache: false)
        } catch {
            // Log or handle quietly
            os_log("Background refresh failed: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Authentication Methods

    func validateToken() async throws {
        guard try isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }
        guard let base = baseURL,
              let token = accessToken else {
            throw AppError(mastodon: .missingCredentials)
        }

        let url = base.appendingPathComponent("/api/v1/accounts/verify_credentials")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response)
    }

    func saveAccessToken(_ token: String) async throws {
        // If there's no baseURL, we can't store contextfully
        guard baseURL != nil else {
            throw AppError(mastodon: .missingCredentials)
        }
        accessToken = token
    }

    func clearAccessToken() async throws {
        guard baseURL != nil else {
            throw AppError(mastodon: .missingCredentials)
        }
        accessToken = nil
    }

    func retrieveAccessToken() async throws -> String? {
        accessToken
    }

    func retrieveInstanceURL() async throws -> URL? {
        baseURL
    }

    // MARK: - Post Actions

    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, path: "/favourite")
    }

    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, path: "/reblog")
    }

    func comment(postID: String, content: String) async throws {
        guard try isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = try endpoint("/api/v1/statuses")
        var req = try buildRequest(url: url, method: "POST")
        let body: [String: Any] = [
            "status": content,
            "in_reply_to_id": postID
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (_, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response)
    }

    // MARK: - OAuth Methods

    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let registerURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request     = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyParams: [String: Any] = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow",
            "website": "https://yourapp.com"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        let decoded = try JSONDecoder().decode(RegisterResponse.self, from: data)
        return OAuthConfig(
            clientID:     decoded.client_id,
            clientSecret: decoded.client_secret,
            redirectURI:  "mustard://oauth-callback",
            scope:        "read write follow"
        )
    }

    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        // Example token endpoint
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        var req      = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  config.redirectURI,
            "client_id":     config.clientID,
            "client_secret": config.clientSecret
            // If needed: "code_verifier": codeVerifier ?? ""
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response)

        let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResp.accessToken
    }

    // MARK: - Streaming Methods

    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard try isAuthenticated(), let localBaseURL = baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }

        // Example public streaming endpoint
        let url     = localBaseURL.appendingPathComponent("/api/v1/streaming/public")
        let request = try buildRequest(url: url, method: "GET")

        return AsyncThrowingStream { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, _, err in
                if let e = err {
                    continuation.finish(throwing: AppError(mastodon: .networkError(underlying: e)))
                    return
                }
                guard let data = data else {
                    continuation.finish(throwing: AppError(mastodon: .invalidResponse))
                    return
                }
                do {
                    let postData = try JSONDecoder().decode(PostData.self, from: data)
                    let post     = postData.toPost(instanceURL: localBaseURL)
                    continuation.yield(post)
                } catch {
                    continuation.finish(throwing: AppError(mastodon: .decodingError))
                }
            }
            task.resume()

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Top Posts Methods

    func fetchTrendingPosts() async throws -> [Post] {
        guard try isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let trendingURL = try endpoint("/api/v1/trends/statuses")
        let request     = try buildRequest(url: trendingURL, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
        return postDataArray.map { $0.toPost(instanceURL: baseURL!) }
    }

    // MARK: - Private Helpers

    /// Helper for toggling like/reblog via POST
    private func toggleAction(for postID: String, path: String) async throws {
        guard try isAuthenticated() else { return }
        let url = try endpoint("/api/v1/statuses/\(postID)\(path)")
        let req = try buildRequest(url: url, method: "POST")
        let (_, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response)
    }

    private func timelineEndpoint(_ slug: String) throws -> URL {
        guard let base = baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }
        return base.appendingPathComponent("/api/v1/timelines/\(slug)")
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let base = baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }
        return base.appendingPathComponent(path)
    }

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let token = accessToken, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Minimal check that baseURL/token exist & are non-empty
    private func isAuthenticated() throws -> Bool {
        guard let base = baseURL,
              let token = accessToken,
              !base.absoluteString.isEmpty,
              !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        return true
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppError(mastodon: .invalidResponse)
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 400:
            throw AppError(mastodon: .badRequest)
        case 401:
            throw AppError(mastodon: .unauthorized)
        case 403:
            throw AppError(mastodon: .forbidden)
        case 404:
            throw AppError(mastodon: .notFound)
        case 500..<600:
            throw AppError(mastodon: .serverError(status: http.statusCode))
        default:
            throw AppError(mastodon: .unknown(status: http.statusCode))
        }
    }

    // MARK: - Keychain/Local Storage

    private func storeBaseURL(_ value: URL?) async {
        do {
            if let url = value {
                try await KeychainHelper.shared.save(
                    url.absoluteString,
                    service: baseURLKeychainService,
                    account: baseURLKeychainAccount
                )
            } else {
                try await KeychainHelper.shared.delete(
                    service: baseURLKeychainService,
                    account: baseURLKeychainAccount
                )
            }
        } catch {
            os_log("Failed to store baseURL: %{public}@", log: logger, type: .error, error.localizedDescription)
            // Possibly log or handle error
        }
    }

    private func loadBaseURL() async -> URL? {
        do {
            if let urlString = try await KeychainHelper.shared.read(service: baseURLKeychainService,
                                                                    account: baseURLKeychainAccount),
               let url = URL(string: urlString) {
                return url
            } else {
                os_log("loadBaseURL: No base URL found in Keychain.", log: logger, type: .error)
            }
        } catch {
            os_log("loadBaseURL: Failed to load base URL: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
        return nil
    }

    private func storeAccessToken(_ token: String?) async {
        guard let base = _baseURL else { return }
        let service = "Mustard-\(base.host ?? "unknown")-accessToken"
        do {
            if let token = token, !token.isEmpty {
                try await KeychainHelper.shared.save(
                    token,
                    service: service,
                    account: accessTokenKeychainAccount
                )
            } else {
                try await KeychainHelper.shared.delete(
                    service: service,
                    account: accessTokenKeychainAccount
                )
            }
        } catch {
            os_log("Failed to store accessToken: %{public}@", log: logger, type: .error, error.localizedDescription)
            // Possibly log or handle error
        }
    }

    private func loadAccessToken() async -> String? {
        guard let base = _baseURL else {
            os_log("loadAccessToken: Base URL is nil.", log: logger, type: .error)
            return nil
        }

        let service = "Mustard-\(base.host ?? "unknown")-accessToken"
        do {
            return try await KeychainHelper.shared.read(service: service, account: accessTokenKeychainAccount)
        } catch {
            os_log("loadAccessToken: Failed to load access token: %{public}@", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Iterate through connected scenes to find the active window scene
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                // Retrieve the key window from the window scene
                if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
            }
        }
        // Fallback to a new UIWindow if no key window is found
        return UIWindow()
    }
}
