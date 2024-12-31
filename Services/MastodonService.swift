//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import AuthenticationServices

/// Represents the response received after successful registration.
struct RegisterResponse: Codable {
    let client_id: String
    let client_secret: String
    // Removed 'access_token' and 'account' as they are not part of the registration response
}

/// OAuth Configuration Details
struct OAuthConfig {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let scope: String
}

/// Represents the response received after obtaining an access token.
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let scope: String
    let created_at: Int
}

/// Represents the authorization response containing the code and state.
struct AuthorizationResponse: Codable {
    let code: String
    let state: String
}

/// Service responsible for interacting with a Mastodon-like backend.
class MastodonService: NSObject, MastodonServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    // MARK: - Properties

    private let baseURLService = "Mustard-baseURL"
    private let baseURLAccount = "baseURL"
    
    var baseURL: URL? {
        get {
            do {
                if let baseURLString = try KeychainHelper.shared.read(service: baseURLService, account: baseURLAccount),
                   let url = URL(string: baseURLString) {
                    return url
                }
            } catch {
                print("[MastodonService] Failed to read BaseURL from Keychain: \(error.localizedDescription)")
            }
            return nil
        }
        set {
            if let url = newValue {
                do {
                    try KeychainHelper.shared.save(url.absoluteString, service: baseURLService, account: baseURLAccount)
                    print("[MastodonService] BaseURL saved: \(url.absoluteString)")
                } catch {
                    print("[MastodonService] Failed to save BaseURL: \(error.localizedDescription)")
                }
            } else {
                do {
                    try KeychainHelper.shared.delete(service: baseURLService, account: baseURLAccount)
                    print("[MastodonService] BaseURL deleted.")
                } catch {
                    print("[MastodonService] Failed to delete BaseURL: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private let accessTokenServicePrefix = "Mustard-"
    private let accessTokenAccount = "accessToken"
    
    var accessToken: String? {
        get {
            guard let baseURL = baseURL else { return nil }
            let service = accessTokenServicePrefix + (baseURL.host ?? "unknown")
            do {
                return try KeychainHelper.shared.read(service: service, account: accessTokenAccount)
            } catch {
                print("[MastodonService] Failed to read access token: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let baseURL = baseURL else {
                print("[MastodonService] BaseURL not set. Cannot set access token.")
                return
            }
            let service = accessTokenServicePrefix + (baseURL.host ?? "unknown")
            if let token = newValue {
                do {
                    try KeychainHelper.shared.save(token, service: service, account: accessTokenAccount)
                    print("[MastodonService] Access token saved for service: \(service)")
                } catch {
                    print("[MastodonService] Failed to save access token: \(error.localizedDescription)")
                }
            } else {
                do {
                    try KeychainHelper.shared.delete(service: service, account: accessTokenAccount)
                    print("[MastodonService] Access token deleted for service: \(service)")
                } catch {
                    print("[MastodonService] Failed to delete access token: \(error.localizedDescription)")
                }
            }
        }
    }

    private var cachedPosts: [Post] = []
    private var cacheFileURL: URL? {
        let fileManager = FileManager.default
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("mustard_timeline.json")
    }
    
    private var isAuthenticatingSession: Bool = false // Flag to prevent multiple sessions

    // MARK: - Initialization

    override init() {
        super.init()
        self.cachedPosts = loadTimelineFromDisk()
    }

    // MARK: - MastodonServiceProtocol Methods

    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        if useCache, !cachedPosts.isEmpty {
            Task.detached { [weak self] in await self?.backgroundRefreshTimeline() }
            return cachedPosts
        }

        guard let baseURL = baseURL, let token = accessToken else {
            print("[MastodonService] fetchTimeline failed: Missing baseURL or accessToken.")
            throw NSError(domain: "MastodonService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing baseURL or accessToken"])
        }

        print("[MastodonService] Fetching timeline for baseURL: \(baseURL.absoluteString)")

        let url = baseURL.appendingPathComponent("/api/v1/timelines/home")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        let postDataArray = try JSONDecoder().decode([PostData].self, from: data)
        let posts = postDataArray.map { $0.toPost(instanceURL: baseURL) } // Pass instanceURL here
        cachedPosts = posts
        saveTimelineToDisk(posts)
        return posts
    }

    func clearTimelineCache() {
        cachedPosts.removeAll()
        guard let cacheFileURL = cacheFileURL else { return }
        do {
            try FileManager.default.removeItem(at: cacheFileURL)
            print("[MastodonService] Timeline cache cleared.")
        } catch {
            print("[MastodonService] Failed to clear timeline cache: \(error.localizedDescription)")
        }
    }

    func loadTimelineFromDisk() -> [Post] {
        guard let fileURL = cacheFileURL else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let posts = try JSONDecoder().decode([Post].self, from: data)
            print("[MastodonService] Loaded timeline from disk with \(posts.count) posts.")
            return posts
        } catch {
            print("[MastodonService] Failed to load timeline from disk: \(error.localizedDescription)")
            return []
        }
    }

    func saveTimelineToDisk(_ posts: [Post]) {
        guard let fileURL = cacheFileURL else { return }
        do {
            let data = try JSONEncoder().encode(posts)
            try data.write(to: fileURL)
            print("[MastodonService] Timeline saved to disk with \(posts.count) posts.")
        } catch {
            print("[MastodonService] Failed to save timeline to disk: \(error.localizedDescription)")
        }
    }

    func backgroundRefreshTimeline() async {
        do {
            _ = try await fetchTimeline(useCache: false)
            print("[MastodonService] Background timeline refresh successful.")
        } catch {
            print("[MastodonService] Background refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Authentication Methods

    func validateToken() async throws {
        guard let baseURL = baseURL, let token = accessToken else {
            throw NSError(domain: "MastodonService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing baseURL or accessToken"])
        }

        let url = baseURL.appendingPathComponent("/api/v1/accounts/verify_credentials")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("[MastodonService] Token validated successfully.")
    }

    func saveAccessToken(_ token: String) throws {
        self.accessToken = token
        print("[MastodonService] Access token saved.")
    }

    func clearAccessToken() throws {
        self.accessToken = nil
        print("[MastodonService] Access token cleared.")
    }

    func retrieveAccessToken() throws -> String? {
        return accessToken
    }

    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }

    // MARK: - Post Actions

    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/favourite")
    }

    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/reblog")
    }

    func comment(postID: String, content: String) async throws {
        guard let baseURL = baseURL, let token = accessToken else {
            throw NSError(domain: "MastodonService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing credentials"])
        }

        let url = baseURL.appendingPathComponent("/api/v1/statuses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["status": content, "in_reply_to_id": postID], options: [])

        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("[MastodonService] Comment posted successfully for postID: \(postID)")
    }

    // MARK: - OAuth Methods

    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let url = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "client_name": "Mustard",
            "redirect_uris": "yourapp://oauth-callback",
            "scopes": "read write follow",
            "website": "https://yourapp.com" // Optional
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
        
        let config = OAuthConfig(
            clientID: registerResponse.client_id,
            clientSecret: registerResponse.client_secret,
            redirectURI: "yourapp://oauth-callback",
            scope: "read write follow"
        )
        
        print("[MastodonService] OAuth App Registered with clientID: \(config.clientID)")
        
        return config
    }

    func authenticateOAuth(instanceURL: URL, config: OAuthConfig) async throws -> String {
        // Construct the OAuth authorization URL
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]

        guard let authorizationURL = components.url else {
            throw NSError(domain: "MastodonService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to construct authorization URL"])
        }

        print("[MastodonService] Starting OAuth session with URL: \(authorizationURL.absoluteString)")

        // Start OAuth session
        return try await performOAuthSession(authURL: authorizationURL, redirectURI: config.redirectURI)
    }

    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParameters = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "client_secret": config.clientSecret
        ]

        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                                       .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveAccessToken(tokenResponse.access_token)

        print("[MastodonService] Access token exchanged and saved successfully.")
    }

    // MARK: - Private Helpers

    private func toggleAction(for postID: String, endpoint: String) async throws {
        guard let baseURL = baseURL, let token = accessToken else {
            print("[MastodonService] toggleAction failed: Missing baseURL or accessToken.")
            throw NSError(domain: "MastodonService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing baseURL or accessToken"])
        }

        let url = baseURL.appendingPathComponent("/api/v1/statuses/\(postID)\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("[MastodonService] Toggled \(endpoint.dropFirst()) for postID: \(postID)")
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "MastodonService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            break
        case 400:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Bad Request."])
        case 401:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your credentials."])
        case 403:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Forbidden."])
        case 404:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Resource not found."])
        case 500...599:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error. Please try again later."])
        default:
            throw NSError(domain: "MastodonService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected error occurred."])
        }
    }
    
    // MARK: - OAuth Session

    private func performOAuthSession(authURL: URL, redirectURI: String) async throws -> String {
        // Prevent multiple authentication sessions
        guard !isAuthenticatingSession else {
            throw NSError(domain: "MastodonService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Authentication session already in progress."])
        }
        isAuthenticatingSession = true
        print("[MastodonService] Starting OAuth session.")

        defer { isAuthenticatingSession = false }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: URL(string: redirectURI)?.scheme) { callbackURL, error in
                if didResume { return }
                didResume = true
                
                if let error = error {
                    print("[MastodonService] OAuth session error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    let error = NSError(domain: "MastodonService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL"])
                    print("[MastodonService] OAuth session failed: Invalid callback URL.")
                    continuation.resume(throwing: error)
                    return
                }
                
                // Parse the authorization code from the callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    let error = NSError(domain: "MastodonService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Authorization code not found"])
                    print("[MastodonService] OAuth session failed: Authorization code not found.")
                    continuation.resume(throwing: error)
                    return
                }
                
                print("[MastodonService] OAuth session successful. Authorization code: \(code)")
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                if !didResume {
                    didResume = true
                    let error = NSError(domain: "MastodonService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"])
                    print("[MastodonService] OAuth session failed to start.")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Provide the current window as the presentation anchor
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            print("[MastodonService] Failed to retrieve presentation anchor. Returning a new UIWindow.")
            return UIWindow()
        }
        return window
    }
}

