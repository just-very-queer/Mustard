//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import AuthenticationServices
import CryptoKit
import OSLog
import SwiftUI

@MainActor
// MARK: - Supporting Types

/// Represents a cached timeline with a timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

// MARK: - Logger

/// Logger for structured and categorized logging.
struct AppLogger {
    static let mastodonService = OSLog(subsystem: "com.yourcompany.Mustard", category: "MastodonService")
}

// MARK: - MastodonService Implementation

enum MastodonServiceError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int)
    case decodingError
    case encodingError
    case networkError(underlying: Error)
    case oauthError(message: String)
    case unknown(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing base URL or access token."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .badRequest:
            return "Bad request."
        case .unauthorized:
            return "Unauthorized access."
        case .forbidden:
            return "Forbidden resource."
        case .notFound:
            return "Resource not found."
        case .serverError(let statusCode):
            return "Server returned an error with status code \(statusCode)."
        case .decodingError:
            return "Failed to decode the response."
        case .encodingError:
            return "Failed to encode the request."
        case .networkError(let underlying):
            return "Network error occurred: \(underlying.localizedDescription)"
        case .oauthError(let message):
            return "OAuth error: \(message)"
        case .unknown(let statusCode):
            return "Unknown error with status code \(statusCode)."
        }
    }
}

@MainActor
class MastodonService: NSObject, MastodonServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Singleton Instance
    
    static let shared = MastodonService()
    
    // MARK: - Properties

    private let baseURLService = "Mustard-baseURL"
    private let baseURLAccount = "baseURL"
    private let accessTokenAccount = "accessToken"
    private var codeVerifier: String?
    private var state: String?
    
    private let logger = AppLogger.mastodonService
    private var isAuthenticatingSession: Bool = false
    private var cachedTimeline: CachedTimeline?
    private var cacheFileURL: URL? {
        let fileManager = FileManager.default
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("mustard_timeline.json")
    }

    // MARK: - Protocol Properties
    
    var baseURL: URL? {
        get {
            os_log("Accessing baseURL: %{public}@", log: logger, type: .debug, _baseURL?.absoluteString ?? "nil")
            return _baseURL
        }
        set {
            _baseURL = newValue
            Task {
                if let url = newValue {
                    do {
                        try await KeychainHelper.shared.save(url.absoluteString, service: baseURLService, account: baseURLAccount)
                        os_log("Base URL saved: %{public}@", log: logger, type: .info, url.absoluteString)
                    } catch {
                        os_log("Failed to save baseURL: %{public}@", log: logger, type: .error, error.localizedDescription)
                    }
                } else {
                    do {
                        try await KeychainHelper.shared.delete(service: baseURLService, account: baseURLAccount)
                        os_log("Base URL deleted.", log: logger, type: .info)
                    } catch {
                        os_log("Failed to delete baseURL: %{public}@", log: logger, type: .error, error.localizedDescription)
                    }
                }
            }
        }
    }
    
    var accessToken: String? {
        get {
            os_log("Accessing accessToken: %{public}@", log: logger, type: .debug, _accessToken ?? "nil")
            return _accessToken
        }
        set {
            _accessToken = newValue
            Task {
                if let token = newValue, let baseURL = self.baseURL {
                    let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
                    do {
                        try await KeychainHelper.shared.save(token, service: service, account: accessTokenAccount)
                        os_log("Access token saved for service: %{public}@", log: logger, type: .info, service)
                    } catch {
                        os_log("Failed to save accessToken: %{public}@", log: logger, type: .error, error.localizedDescription)
                    }
                } else if let baseURL = self.baseURL {
                    let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
                    do {
                        try await KeychainHelper.shared.delete(service: service, account: accessTokenAccount)
                        os_log("Access token deleted for service: %{public}@", log: logger, type: .info, service)
                    } catch {
                        os_log("Failed to delete accessToken: %{public}@", log: logger, type: .error, error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private var _baseURL: URL?
    private var _accessToken: String?
    
    // MARK: - Initialization

    private override init() {
        super.init()
        Task {
            do {
                self._baseURL = try await loadBaseURL()
                self._accessToken = try await loadAccessToken()
                os_log("MastodonService initialized with baseURL: %{public}@ and accessToken: %{public}@", log: logger, type: .info, self._baseURL?.absoluteString ?? "nil", self._accessToken ?? "nil")
            } catch {
                os_log("Failed to load credentials during initialization: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
    }

    // MARK: - MastodonServiceProtocol Methods

    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        if useCache, let cache = cachedTimeline, Date().timeIntervalSince(cache.timestamp) < 300 {
            Task.detached { [weak self] in
                await self?.backgroundRefreshTimeline()
            }
            return cache.posts
        }

        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            os_log("Missing baseURL or accessToken.", log: logger, type: .error)
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/timelines/home")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)

            let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
            let posts = postDataArray.map { $0.toPost(instanceURL: baseURL) }
            cachedTimeline = CachedTimeline(posts: posts, timestamp: Date())
            try await saveTimelineToDisk(posts)
            os_log("Fetched timeline with %{public}d posts.", log: logger, type: .info, posts.count)
            return posts
        } catch {
            if let serviceError = error as? MastodonServiceError {
                os_log("Failed to fetch timeline: %{public}@", log: logger, type: .error, serviceError.localizedDescription)
                throw serviceError
            } else {
                os_log("Network error: %{public}@", log: logger, type: .error, error.localizedDescription)
                throw MastodonServiceError.networkError(underlying: error)
            }
        }
    }
    
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            os_log("Missing baseURL or accessToken.", log: logger, type: .error)
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/timelines/home")
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "limit", value: "20")
        ]
        
        if page > 1, let lastPost = cachedTimeline?.posts.last {
            queryItems.append(URLQueryItem(name: "max_id", value: lastPost.id))
        }
        
        components.queryItems = queryItems
        
        guard let finalURL = components.url else {
            throw MastodonServiceError.encodingError
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            
            let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
            let posts = postDataArray.map { $0.toPost(instanceURL: baseURL) }
            return posts
        } catch {
            if let serviceError = error as? MastodonServiceError {
                os_log("Failed to fetch timeline page %{public}d: %{public}@", log: logger, type: .error, page, serviceError.localizedDescription)
                throw serviceError
            } else {
                os_log("Network error while fetching timeline page %{public}d: %{public}@", log: logger, type: .error, page, error.localizedDescription)
                throw MastodonServiceError.networkError(underlying: error)
            }
        }
    }

    func clearTimelineCache() async throws {
        cachedTimeline = nil
        guard let cacheFileURL = cacheFileURL else { return }
        do {
            try FileManager.default.removeItem(at: cacheFileURL)
            os_log("Timeline cache cleared.", log: logger, type: .info)
        } catch {
            os_log("Failed to clear timeline cache: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func loadTimelineFromDisk() async throws -> [Post] {
        guard let fileURL = cacheFileURL else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let posts = try JSONDecoder().decode([Post].self, from: data)
            os_log("Loaded timeline from disk with %{public}d posts.", log: logger, type: .info, posts.count)
            return posts
        } catch {
            os_log("Failed to load timeline from disk: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func saveTimelineToDisk(_ posts: [Post]) async throws {
        guard let fileURL = cacheFileURL else { return }
        do {
            let data = try JSONEncoder().encode(posts)
            try data.write(to: fileURL)
            os_log("Timeline saved to disk with %{public}d posts.", log: logger, type: .info, posts.count)
        } catch {
            os_log("Failed to save timeline to disk: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.encodingError
        }
    }

    func backgroundRefreshTimeline() async {
        do {
            let freshPosts = try await fetchTimeline(useCache: false)
            os_log("Background timeline refresh successful with %{public}d posts.", log: logger, type: .info, freshPosts.count)
        } catch {
            os_log("Background timeline refresh failed: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }

    func validateToken() async throws {
        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            os_log("Token validated successfully.", log: logger, type: .info)
        } catch {
            os_log("Token validation failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func saveAccessToken(_ token: String) async throws {
        guard let baseURL = self.baseURL else {
            throw MastodonServiceError.missingCredentials
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
        do {
            try await KeychainHelper.shared.save(token, service: service, account: accessTokenAccount)
            os_log("Access token saved for service: %{public}@", log: logger, type: .info, service)
        } catch {
            os_log("Failed to save access token: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func clearAccessToken() async throws {
        guard let baseURL = self.baseURL else {
            throw MastodonServiceError.missingCredentials
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
        do {
            try await KeychainHelper.shared.delete(service: service, account: accessTokenAccount)
            os_log("Access token deleted for service: %{public}@", log: logger, type: .info, service)
        } catch {
            os_log("Failed to delete access token: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func retrieveAccessToken() async throws -> String? {
        guard let baseURL = self.baseURL else { return nil }
        let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
        do {
            let token = try await KeychainHelper.shared.read(service: service, account: accessTokenAccount)
            os_log("Access token retrieved: %{public}@", log: logger, type: .debug, token ?? "nil")
            return token
        } catch {
            os_log("Failed to read access token: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func retrieveInstanceURL() async throws -> URL? {
        do {
            let urlString = try await KeychainHelper.shared.read(service: baseURLService, account: baseURLAccount)
            if let urlString = urlString, let url = URL(string: urlString) {
                os_log("Instance URL retrieved: %{public}@", log: logger, type: .debug, urlString)
                return url
            }
            os_log("Instance URL not found.", log: logger, type: .info)
            return nil
        } catch {
            os_log("Failed to read BaseURL from Keychain: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/favourite")
    }

    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/reblog")
    }

    func comment(postID: String, content: String) async throws {
        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/statuses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "status": content,
            "in_reply_to_id": postID
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw MastodonServiceError.encodingError
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            os_log("Comment posted successfully for postID: %{public}@", log: logger, type: .info, postID)
        } catch {
            os_log("Failed to post comment: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let url = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow",
            "website": "https://yourapp.com" // Optional
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw MastodonServiceError.encodingError
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
            let config = OAuthConfig(
                clientID: registerResponse.client_id,
                clientSecret: registerResponse.client_secret,
                redirectURI: "mustard://oauth-callback",
                scope: "read write follow"
            )
            os_log("OAuth App Registered with clientID: %{public}@", log: logger, type: .info, config.clientID)
            return config
        } catch {
            os_log("Failed to register OAuth App: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw MastodonServiceError.networkError(underlying: error)
        }
    }

    func authenticateOAuth(instanceURL: URL, config: OAuthConfig) async throws -> String {
        guard !isAuthenticatingSession else {
            throw MastodonServiceError.oauthError(message: "Authentication session already in progress.")
        }

        isAuthenticatingSession = true
        defer { isAuthenticatingSession = false }
            
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        let state = UUID().uuidString
        self.state = state
        self.codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier!)

        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authorizationURL = components.url else {
            throw MastodonServiceError.oauthError(message: "Failed to construct authorization URL.")
        }

        os_log("Starting OAuth session with URL: %{public}@", log: logger, type: .info, authorizationURL.absoluteString)

        let code = try await performOAuthSession(authURL: authorizationURL, redirectURI: config.redirectURI)
        
        // After obtaining the authorization code, exchange it for an access token
        try await exchangeAuthorizationCode(code, config: config, instanceURL: instanceURL)
        
        // Set the baseURL and accessToken
        self.baseURL = instanceURL
        self.accessToken = try await retrieveAccessToken() // Ensure it's set
        
        // Post the authentication notification
        NotificationCenter.default.post(name: .didAuthenticate, object: nil)
        
        os_log("OAuth authentication flow completed successfully.", log: logger, type: .info)
        
        return code
    }

    // MARK: - Private Helpers

    private func toggleAction(for postID: String, endpoint: String) async throws {
        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            os_log("Missing baseURL or accessToken.", log: logger, type: .error)
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/statuses/\(postID)\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response)
            os_log("Toggled %{public}@ for postID: %{public}@", log: logger, type: .info, String(endpoint.dropFirst()), postID)
        } catch {
            if let serviceError = error as? MastodonServiceError {
                os_log("Failed to toggle %{public}@ : %{public}@", log: logger, type: .error, String(endpoint.dropFirst()), serviceError.localizedDescription)
                throw serviceError
            } else {
                os_log("Network error: %{public}@", log: logger, type: .error, error.localizedDescription)
                throw MastodonServiceError.networkError(underlying: error)
            }
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MastodonServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            break
        case 400:
            throw MastodonServiceError.badRequest
        case 401:
            throw MastodonServiceError.unauthorized
        case 403:
            throw MastodonServiceError.forbidden
        case 404:
            throw MastodonServiceError.notFound
        case 500...599:
            throw MastodonServiceError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw MastodonServiceError.unknown(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - OAuth Session

    private func performOAuthSession(authURL: URL, redirectURI: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: URL(string: redirectURI)?.scheme) { callbackURL, error in
                if let error = error {
                    os_log("OAuth session error: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL else {
                    let error = MastodonServiceError.oauthError(message: "Invalid callback URL.")
                    os_log("OAuth session failed: Invalid callback URL.", log: self.logger, type: .error)
                    continuation.resume(throwing: error)
                    return
                }

                // Verify state
                guard let receivedState = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "state" })?.value,
                      receivedState == self.state else {
                    let error = MastodonServiceError.oauthError(message: "State mismatch.")
                    os_log("OAuth session failed: State mismatch.", log: self.logger, type: .error)
                    continuation.resume(throwing: error)
                    return
                }

                // Parse the authorization code from the callback URL
                guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?.value else {
                    let error = MastodonServiceError.oauthError(message: "Authorization code not found.")
                    os_log("OAuth session failed: Authorization code not found.", log: self.logger, type: .error)
                    continuation.resume(throwing: error)
                    return
                }

                os_log("OAuth session successful. Authorization code: %{public}@", log: self.logger, type: .info, code)
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                let error = MastodonServiceError.oauthError(message: "Failed to start authentication session.")
                os_log("OAuth session failed to start.", log: self.logger, type: .error)
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<128).map { _ in characters.randomElement()! })
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        
        // Encode to Base64
        var base64 = Data(hash).base64EncodedString()
        
        // Convert to Base64 URL encoding by replacing '+' with '-', '/' with '_', and removing padding '='
        base64 = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return base64
    }

    // MARK: - Streaming

    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard let baseURL = self.baseURL,
              let token = self.accessToken else {
            throw MastodonServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent("/api/v1/streaming/public")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return AsyncThrowingStream { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    os_log("Streaming error: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    continuation.finish(throwing: MastodonServiceError.networkError(underlying: error))
                    return
                }

                guard let data = data else {
                    os_log("Streaming error: No data received.", log: self.logger, type: .error)
                    continuation.finish(throwing: MastodonServiceError.invalidResponse)
                    return
                }

                do {
                    let postData = try JSONDecoder().decode(PostData.self, from: data)
                    let post = postData.toPost(instanceURL: baseURL)
                    continuation.yield(post)
                } catch {
                    os_log("Streaming decoding error: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    continuation.finish(throwing: MastodonServiceError.decodingError)
                }
            }

            task.resume()

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Provide the current window as the presentation anchor
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            os_log("Failed to retrieve presentation anchor. Returning a new UIWindow.", log: logger, type: .error)
            return UIWindow()
        }
        return window
    }
    
    // MARK: - Private Keychain Operations
    
    private func loadBaseURL() async throws -> URL? {
        let urlString = try await KeychainHelper.shared.read(service: baseURLService, account: baseURLAccount)
        if let urlString = urlString, let url = URL(string: urlString) {
            return url
        }
        return nil
    }
    
    private func loadAccessToken() async throws -> String? {
        guard let baseURL = self.baseURL else { return nil }
        let service = "Mustard-\(baseURL.host ?? "unknown")-accessToken"
        let token = try await KeychainHelper.shared.read(service: service, account: accessTokenAccount)
        return token
    }
}
