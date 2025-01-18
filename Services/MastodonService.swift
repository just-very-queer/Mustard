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
import CoreLocation

@MainActor
class MastodonService: NSObject, MastodonServiceProtocol, ASWebAuthenticationPresentationContextProviding {

    
    // MARK: - Singleton & Properties
    static let shared = MastodonService()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "MastodonService")
    private let keychainService = "MustardKeychain"
    private var tokenCreationDate: Date?
    private var rateLimiter = RateLimiter(capacity: 40, refillRate: 1.0) // Example: 40 requests per second
    private let requestQueue = OperationQueue()
    private var streamingTasks: [URLSessionDataTask] = []
    private let cacheQueue = DispatchQueue(label: "com.yourcompany.Mustard.CacheQueue", qos: .background)
    private let timelineCache = NSCache<NSString, NSArray>()
    private let trendingPostsCache = NSCache<NSString, NSArray>()
    private let cacheDirectoryName = "com.yourcompany.Mustard.datacache"


    private var _baseURL: URL?
    private var _accessToken: String?
    private var cachedTimeline: CachedTimeline?
    
    // Custom JSONEncoder/Decoder for Mastodon API
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    override init() {
        super.init()
    }
    
    
    // MARK: - MastodonServiceProtocol Properties
    var baseURL: URL? {
        get { _baseURL }
        set { _baseURL = newValue; Task { await saveToKeychain(key: "baseURL", value: newValue?.absoluteString) } }
    }
    
    var accessToken: String? {
        get { _accessToken }
        set { _accessToken = newValue; Task { await saveToKeychain(key: "accessToken", value: newValue) } }
    }
    
    // MARK: - Initialization & Authentication
    func ensureInitialized() async throws {
        _baseURL = await loadFromKeychain(key: "baseURL").flatMap(URL.init)
        _accessToken = await loadFromKeychain(key: "accessToken")

        // Check if the instance URL is nil, then clear all data from Keychain
        if _baseURL == nil || _accessToken == nil {
            try await clearAllKeychainData()
            // Additional error thrown to indicate that credentials are not just missing but also cleared
            throw AppError(mastodon: .missingOrClearedCredentials)
        }
    }
    
    func isAuthenticated() async throws -> Bool {
        guard let base = baseURL, let token = accessToken, !base.absoluteString.isEmpty, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        return true
    }
    
    // MARK: - Timeline Methods
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        guard try await isAuthenticated() else {
            throw AppError(mastodon: .missingCredentials)
        }

        let cacheKey = "timeline" as NSString

        do {
            let cachedPosts = try await loadTimelineFromDisk()
            Task { await backgroundRefreshTimeline() }
            // Put loaded posts into in-memory cache
            timelineCache.setObject(cachedPosts as NSArray, forKey: cacheKey)
            return cachedPosts
        } catch let error as AppError {
            // Add type annotation to disambiguate the error
            if case .mastodon(.cacheNotFound) = error.type {
                // Cache not found, continue to fetch from network
                logger.info("Timeline cache not found on disk. Fetching from network.")
            } else {
                // Handle other errors (e.g., decoding error)
                logger.error("Error loading timeline from disk: \(error)")
                throw error // Or handle it appropriately
            }
        }

        // Fetch from network
        let posts = try await fetchData(endpoint: "/api/v1/timelines/home", type: [Post].self)
        cacheTimeline(posts) // Cache the fetched timeline both in memory and on disk

        // Save to disk in the background
        Task {
            await saveTimelineToDisk(posts)
        }

        return posts
    }
    
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        guard try await isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        var endpoint = "/api/v1/timelines/home"

        if page > 1 {
            if let lastID = (timelineCache.object(forKey: "timeline" as NSString) as? [Post])?.last?.id {
                endpoint += "?max_id=\(lastID)"
            } else if let lastID = try? await loadTimelineFromDisk().last?.id { // Use try? to handle potential error.
                endpoint += "?max_id=\(lastID)"
            }
        }

        let posts = try await fetchData(endpoint: endpoint, type: [Post].self)
        if !posts.isEmpty {
            // Update in-memory cache for next page requests
            let updatedPosts = (timelineCache.object(forKey: "timeline" as NSString) as? [Post] ?? []) + posts
            timelineCache.setObject(updatedPosts as NSArray, forKey: "timeline" as NSString)

            // Save the updated timeline to disk in the background
            Task {
                await saveTimelineToDisk(updatedPosts)
            }
        }

        return posts
    }
    
    func clearTimelineCache() {
        timelineCache.removeAllObjects() // Clear in-memory cache
        Task {
            await clearTimelineDiskCache() // Clear disk cache
        }
    }

    
    func loadTimelineFromDisk() async throws -> [Post] {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(cacheDirectoryName)/timelineCache.json")

        guard let data = try? Data(contentsOf: fileURL) else {
            throw AppError(mastodon: .cacheNotFound, underlyingError: nil) // Throw error if no cached data
        }

        do {
            let posts = try jsonDecoder.decode([Post].self, from: data)
            return posts
        } catch {
            throw AppError(mastodon: .decodingError, underlyingError: error)
        }
    }

    func saveTimelineToDisk(_ posts: [Post]) async {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)

        do {
            if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
                try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
            }

            let fileURL = cacheDirectoryURL.appendingPathComponent("timelineCache.json")
            let data = try jsonEncoder.encode(posts)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Failed to save timeline to disk: \(error.localizedDescription)")
        }
    }

    func backgroundRefreshTimeline() async {
        do {
            let fetchedPosts = try await fetchData(endpoint: "/api/v1/timelines/home", type: [Post].self)
            if !fetchedPosts.isEmpty {
                cacheTimeline(fetchedPosts)
                // Save to disk in the background
                Task {
                    await saveTimelineToDisk(fetchedPosts)
                }
            }
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
        }
    }
    
    func fetchTrendingPosts() async throws -> [Post] {
        let cacheKey = "trendingPosts" as NSString

        // Try to get from in-memory cache
        if let cachedPosts = trendingPostsCache.object(forKey: cacheKey) as? [Post] {
            return cachedPosts
        }

        // Try to load from disk
        if let diskCachedPosts = await loadTrendingPostsFromDisk() {
            // Put loaded posts into in-memory cache
            trendingPostsCache.setObject(diskCachedPosts as NSArray, forKey: cacheKey)
            return diskCachedPosts
        }

        // Fetch from network
        let posts = try await fetchData(endpoint: "/api/v1/trends/statuses", type: [Post].self)
        cacheTrendingPosts(posts) // Cache the fetched trending posts

        return posts
    }

    // MARK: - Post Actions
    func toggleLike(postID: String) async throws {
        try await postAction(for: postID, path: "/favourite")
        // Update the cache after successfully liking a post
        try await updatePostInCache(postID: postID) { post in
            post.isFavourited.toggle()
            post.favouritesCount += post.isFavourited ? 1 : -1
        }
    }

    func toggleRepost(postID: String) async throws {
        try await postAction(for: postID, path: "/reblog")
        // Update the cache after successfully reposting a post
        try await updatePostInCache(postID: postID) { post in
            post.isReblogged.toggle()
            post.reblogsCount += post.isReblogged ? 1 : -1
        }
    }

    func comment(postID: String, content: String) async throws {
        let body: [String: String] = ["status": content, "in_reply_to_id": postID]
        _ = try await postData(endpoint: "/api/v1/statuses", body: body, type: Post.self)
        // Update the cache after successfully commenting on a post
        try await updatePostInCache(postID: postID) { post in
            post.repliesCount += 1
        }
    }

    // MARK: - OAuth Methods
    
    /// Registers the app with the specified Mastodon instance to get OAuth client credentials.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "MastodonService")
        logger.info("Attempting to register OAuth app with instance: \(instanceURL)")

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
            logger.error("Error creating request body: \(error)")
            throw AppError(mastodon: .encodingError, underlyingError: error)
        }

        logger.info("Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Response was not an HTTPURLResponse")
            throw AppError(mastodon: .invalidResponse)
        }

        logger.info("HTTP Status Code: \(httpResponse.statusCode)")

        // Handle different status codes more specifically
        switch httpResponse.statusCode {
        case 200:
            // Successful registration
            if let responseString = String(data: data, encoding: .utf8) {
                logger.info("Response body: \(responseString)")
            }

            let registerResponse: RegisterResponse
            do {
                registerResponse = try jsonDecoder.decode(RegisterResponse.self, from: data)
            } catch {
                logger.error("Error decoding response: \(error)")
                throw AppError(mastodon: .decodingError, underlyingError: error)
            }

            // Ensure that either redirect_uri or redirect_uris is present
            guard let redirectURI = registerResponse.redirect_uri ?? registerResponse.redirect_uris?.first else {
                logger.error("No redirect URI found in response")
                throw AppError(mastodon: .invalidResponse, underlyingError: nil)
            }

            let config = OAuthConfig(
                clientID: registerResponse.client_id,
                clientSecret: registerResponse.client_secret,
                redirectURI: redirectURI, // Use the non-optional redirectURI
                scope: "read write follow"
            )

            logger.info("Successfully registered OAuth app with client ID: \(config.clientID)")
            return config

        case 401:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode) - Unauthorized")
            throw AppError(mastodon: .unauthorized)
        case 403:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode) - Forbidden")
            throw AppError(mastodon: .forbidden)
        case 404:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode) - Not Found")
            throw AppError(mastodon: .notFound)
        case 422:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode) - Unprocessable Entity")
            // You might want to inspect the response body here to provide more details to the user
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Response body: \(responseString)")
            }
            throw AppError(mastodon: .badRequest)
        case 500...599:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode) - Server Error")
            throw AppError(mastodon: .serverError(status: httpResponse.statusCode))

        default:
            logger.error("Failed to register OAuth app. HTTP Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Response body: \(responseString)")
            }
            throw AppError(mastodon: .failedToRegisterOAuthApp)
        }
    }
    /// Exchanges the authorization code for an access token.
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
           let body = [
               "grant_type": "authorization_code",
               "code": code,
               "client_id": config.clientID,
               "client_secret": config.clientSecret,
               "redirect_uri": config.redirectURI,
               "scope": config.scope // Include scope
           ]
           let requestURL = instanceURL.appendingPathComponent("/oauth/token")
           var request = URLRequest(url: requestURL)
           request.httpMethod = "POST"
           request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

           // Correctly construct the request body
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

           // Decode the token response using the updated struct with CodingKeys
           let tokenResponse = try jsonDecoder.decode(TokenResponse.self, from: data)
           self.accessToken = tokenResponse.accessToken
           self.tokenCreationDate = Date() // Store the token creation date

           // Fetch and save the instance URL after successful token exchange
           self.baseURL = instanceURL
           logger.info("Successfully exchanged authorization code for access token.")
       }
    
    func isTokenNearExpiry() -> Bool {
        guard let creationDate = tokenCreationDate else { return true } // Treat as expired if no creation date
        let expiryThreshold = TimeInterval(3600 * 24 * 80)  // 80 days for example (adjust as needed)
        return Date().timeIntervalSince(creationDate) > expiryThreshold
    }

    func reauthenticate(config: OAuthConfig, instanceURL: URL) async throws {
        // Clear existing credentials
        try await clearAccessToken()
        _baseURL = nil
        tokenCreationDate = nil

        // Start a new web authentication session to get a new authorization code
        let authorizationCode = try await startWebAuthSession(config: config, instanceURL: instanceURL)
        logger.info("Received new authorization code.")

        // Exchange the new authorization code for a new access token
        try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: instanceURL)
        logger.info("Exchanged new authorization code for access token.")

        // Fetch and update the current user details
        let updatedUser = try await fetchCurrentUser()
        NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": updatedUser])
        logger.info("Fetched and updated current user: \(updatedUser.username)")
    }

    
    // MARK: - User Methods

    func fetchCurrentUser() async throws -> User {
        guard try await isAuthenticated() else { throw AppError(mastodon: .missingCredentials) }
        let user = try await fetchData(endpoint: "/api/v1/accounts/verify_credentials", type: User.self)
        // Cache the fetched user (if needed)
        return user
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
        return await loadFromKeychain(key: "accessToken")
    }

    func retrieveInstanceURL() async throws -> URL? {
        return await loadFromKeychain(key: "baseURL").flatMap(URL.init)
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }

    // MARK: - Helper Methods
    private func saveToKeychain(key: String, value: String?) async {
        guard let value = value else { return }
        do {
            try await KeychainHelper.shared.save(value, service: keychainService, account: key)
            logger.debug("Saved \(key) to Keychain.")
        } catch {
            logger.error("Failed to save \(key) to Keychain: \(error.localizedDescription)")
        }
    }

    private func loadFromKeychain(key: String) async -> String? {
        do {
            return try await KeychainHelper.shared.read(service: keychainService, account: key)
        } catch {
            logger.error("Failed to load \(key) from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    func clearAllKeychainData() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
    }

    // MARK: - Cache Helpers

    private func cacheTimeline(_ posts: [Post]) {
        let cacheKey = "timeline" as NSString
        timelineCache.setObject(posts as NSArray, forKey: cacheKey)
        Task {
            await saveTimelineToDisk(posts)
        }
    }

    private func cacheTrendingPosts(_ posts: [Post]) {
        let cacheKey = "trendingPosts" as NSString
        trendingPostsCache.setObject(posts as NSArray, forKey: cacheKey)
        Task {
            await saveTrendingPostsToDisk(posts)
        }
    }

    private func clearTimelineDiskCache() async {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)
        let fileURL = cacheDirectoryURL.appendingPathComponent("timelineCache.json")

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                logger.info("Timeline disk cache cleared.")
            }
        } catch {
                logger.error("Failed to clear timeline disk cache: \(error.localizedDescription)")
            }
        }

        private func loadTrendingPostsFromDisk() async -> [Post]? {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(cacheDirectoryName)/trendingPostsCache.json")
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? jsonDecoder.decode([Post].self, from: data)
        }

        private func saveTrendingPostsToDisk(_ posts: [Post]) async {
            guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)

            do {
                if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
                    try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
                }

                let fileURL = cacheDirectoryURL.appendingPathComponent("trendingPostsCache.json")
                let data = try jsonEncoder.encode(posts)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                logger.error("Failed to save trending posts to disk: \(error.localizedDescription)")
            }
        }

    private func updatePostInCache(postID: String, update: (inout Post) -> Void) async throws {
        let timelineCacheKey = "timeline" as NSString
        let trendingPostsCacheKey = "trendingPosts" as NSString

        // Update in-memory cache for timeline posts
        if var timelinePosts = timelineCache.object(forKey: timelineCacheKey) as? [Post],
            let index = timelinePosts.firstIndex(where: { $0.id == postID }) {
            update(&timelinePosts[index])
            timelineCache.setObject(timelinePosts as NSArray, forKey: timelineCacheKey)
        }

        // Update in-memory cache for trending posts
        if var trendingPosts = trendingPostsCache.object(forKey: trendingPostsCacheKey) as? [Post],
            let index = trendingPosts.firstIndex(where: { $0.id == postID }) {
            update(&trendingPosts[index])
            trendingPostsCache.setObject(trendingPosts as NSArray, forKey: trendingPostsCacheKey)
        }

        // Update disk cache for timeline posts
        do {
            var diskTimelinePosts = try await loadTimelineFromDisk()
            if let index = diskTimelinePosts.firstIndex(where: { $0.id == postID }) {
                update(&diskTimelinePosts[index])
                await saveTimelineToDisk(diskTimelinePosts)
            }
        } catch {
            logger.error("Failed to update post in timeline disk cache: \(error.localizedDescription)")
            throw error // Re-throw the error after logging
        }

        // Update disk cache for trending posts
        do {
            if var diskTrendingPosts = await loadTrendingPostsFromDisk(), let index = diskTrendingPosts.firstIndex(where: { $0.id == postID}) {
                update(&diskTrendingPosts[index])
                await saveTrendingPostsToDisk(diskTrendingPosts)
            }
        } catch {
            logger.error("Failed to update post in trending posts disk cache: \(error.localizedDescription)")
            // Optionally re-throw the error, or handle it silently
            throw error
        }
    }

    // MARK: - Networking Helpers

    private func fetchData<T: Decodable>(endpoint: String, type: T.Type) async throws -> T {
        // Check rate limit before making the request
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }

        let url = try endpointURL(endpoint)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func postData<T: Decodable>(
        endpoint: String,
        body: [String: String],
        type: T.Type,
        baseURLOverride: URL? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        // Check rate limit before making the request
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }

        let url = try endpointURL(endpoint, baseURLOverride: baseURLOverride)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try buildBody(body: body, contentType: contentType)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func postAction(for postID: String, path: String) async throws {
        // Check rate limit before making the request
        guard rateLimiter.tryConsume() else {
            throw AppError(mastodon: .rateLimitExceeded)
        }

        let url = try endpointURL("/api/v1/statuses/\(postID)\(path)")
        let request = try buildRequest(url: url, method: "POST")
        _ = try await URLSession.shared.data(for: request)
    }

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

    private func endpointURL(_ path: String, baseURLOverride: URL? = nil) throws -> URL {
        guard let base = baseURLOverride ?? baseURL else { throw AppError(mastodon: .missingCredentials) }
        return base.appendingPathComponent(path)
    }

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let token = accessToken else { throw AppError(mastodon: .missingCredentials) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.error("Invalid or server error response.")
            throw AppError(mastodon: .invalidResponse)
        }
    }

    // MARK: - OAuth Helper Methods
    private func oauthRegisterBody() -> [String: String] {
        return [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow"
        ]
    }

    private func oauthExchangeBody(code: String, config: OAuthConfig) -> [String: String] {
        return [
            "client_id": config.clientID,
            "client_secret": config.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectURI
        ]
    }
        
    /// Starts the Web Authentication Session to retrieve the authorization code.
    private func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]
            
        guard let finalURL = components.url else {
            throw AppError(mastodon: .invalidAuthorizationCode, underlyingError: nil)
        }
            
        guard let redirectScheme = URL(string: config.redirectURI)?.scheme else {
            throw AppError(mastodon: .invalidResponse, underlyingError: nil)
        }
            
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    self.logger.error("ASWebAuthenticationSession error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: error.localizedDescription), underlyingError: error))
                    return
                }
                
                guard let callbackURL = callbackURL,
                    let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.logger.error("Authorization code not found in callback URL.")
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Authorization code not found."), underlyingError: nil))
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            
            if !session.start() {
                self.logger.error("ASWebAuthenticationSession failed to start.")
                continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Failed to start WebAuth session."), underlyingError: nil))
            }
        }
    }

    
    // MARK: - Stream Functionality
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard try await isAuthenticated(), let baseURL = baseURL else {
            throw AppError(mastodon: .missingCredentials)
        }

        let streamingURL = baseURL.appendingPathComponent("/api/v1/streaming/user")
        var request = try buildRequest(url: streamingURL, method: "GET")
        // In `buildRequest`, set the timeout interval:
        request.timeoutInterval = Double.infinity

        
        return AsyncThrowingStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish(throwing: AppError(mastodon: .unknown(status: 0)))
                return
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    continuation.finish(throwing: AppError(mastodon: .invalidResponse))
                    return
                }

                guard let data = data else {
                    continuation.finish(throwing: AppError(mastodon: .invalidResponse))
                    return
                }

                self.processStreamingData(data, continuation: continuation)
            }

            task.resume()
            self.streamingTasks.append(task)

            continuation.onTermination = { @Sendable [weak self] _ in
                task.cancel()
                Task {
                    await MainActor.run {self?.streamingTasks.removeAll(where: { $0 == task })
                    }
                }
            }
        }
    }

    private func processStreamingData(_ data: Data, continuation: AsyncThrowingStream<Post, Error>.Continuation) {
        guard let stringData = String(data: data, encoding: .utf8) else {
            continuation.finish(throwing: AppError(mastodon: .decodingError))
            return
        }

        let lines = stringData.components(separatedBy: "\n")

        for line in lines {
            if line.hasPrefix("event: update") {
                if let dataLine = lines.first(where: { $0.hasPrefix("data: ") }) {
                    let jsonData = dataLine.dropFirst(6).data(using: .utf8)!
                    do {
                        let post = try self.jsonDecoder.decode(Post.self, from: jsonData)
                        continuation.yield(post)
                    } catch {
                        print("Error decoding post: \(error)")
                        continuation.finish(throwing: AppError(mastodon: .decodingError))
                    }
                }
            } else if line.hasPrefix("event: notification") {
                // TODO: Handle other events as needed
            }
        }
    }

    // MARK: - Supporting Structs
    private struct CachedTimeline {
        let posts: [Post]
        let timestamp: Date
    }

    struct RegisterResponse: Codable, Sendable {
        let id: String?
        let name: String?
        let website: String?
        let vapid_key: String?
        let client_id: String
        let client_secret: String
        let redirect_uri: String?
        let redirect_uris: [String]?

        enum CodingKeys: String, CodingKey {
            case id, name, website, vapid_key
            case client_id
            case client_secret
            case redirect_uri
            case redirect_uris
        }
    }
        
    struct TokenResponse: Codable, Sendable {
            let access_token: String

            /// Convenience property to access `access_token`.
            var accessToken: String { access_token }

            // Add CodingKeys here
            enum CodingKeys: String, CodingKey {
                case access_token
            }
    }
}

class RateLimiter {
    private let capacity: Int
    private let refillRate: Double // Tokens per second
    private var tokens: Double
    private var lastRefillTime: Date

    init(capacity: Int, refillRate: Double) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = Double(capacity)
        self.lastRefillTime = Date()
    }

    func tryConsume(tokens: Int = 1) -> Bool {
        refill()
        if Double(tokens) <= self.tokens {
            self.tokens -= Double(tokens)
            return true
        } else {
            return false
        }
    }

    private func refill() {
        let now = Date()
        let timeSinceLastRefill = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timeSinceLastRefill * refillRate
        self.tokens = min(Double(capacity), self.tokens + tokensToAdd)
        self.lastRefillTime = now
    }
}
