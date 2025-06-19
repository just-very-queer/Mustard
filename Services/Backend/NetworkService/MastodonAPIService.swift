//
//  MastodonAPIService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 17/04/25.
//

import Foundation
import OSLog

// Assuming PostVisibility is defined in MastodonAPIServiceProtocol.swift or a shared Model file.
// If not, it would need to be defined or imported here.
// For example:
// enum PostVisibility: String, Codable { /* cases */ }
//
// Assuming Post is a Decodable struct defined elsewhere.

public class MastodonAPIService: MastodonAPIServiceProtocol { // Conform to the protocol
    // MARK: - Shared Instance
    public static let shared = MastodonAPIService() // Added singleton shared instance

    // MARK: - Dependencies
    private let sessionManager: NetworkSessionManager
    private let keychainHelper: KeychainHelper
    private let keychainService = "MustardKeychain" // Consistent Keychain service name
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "MastodonAPIService")

    // MARK: - Initialization
    /// Initializes with required dependencies.
    /// - Parameters:
    ///   - sessionManager: The core network session handler. Defaults to shared instance.
    ///   - keychainHelper: The keychain access helper. Defaults to shared instance.
    internal init(
        sessionManager: NetworkSessionManager = .shared,
        keychainHelper: KeychainHelper = .shared
    ) {
        self.sessionManager = sessionManager
        self.keychainHelper = keychainHelper
    }

    // MARK: - Helper Methods

    /// Fetches the current access token from Keychain.
    private func fetchAccessToken() async -> String? {
        do {
            return try await keychainHelper.read(service: keychainService, account: "accessToken")
        } catch {
            logger.error("Failed to fetch access token from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches the base URL from Keychain.
    private func getBaseURL() async throws -> URL {
        guard let baseURLString = try await keychainHelper.read(service: keychainService, account: "baseURL"),
              let url = URL(string: baseURLString) else {
            logger.error("Base URL not found or invalid in Keychain.")
            throw AppError(mastodon: .missingCredentials)
        }
        return url
    }

    /// Constructs a full URL for a given API path and optional query items.
    func endpointURL(_ path: String, baseURLOverride: URL? = nil, queryItems: [URLQueryItem]? = nil) async throws -> URL {
        let baseURL: URL
        if let override = baseURLOverride {
            baseURL = override
        } else {
            baseURL = try await getBaseURL()
        }

        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        // Append existing query items from path if any, then add new ones
        var existingQueryItems = urlComponents?.queryItems ?? []
        if let newQueryItems = queryItems {
            existingQueryItems.append(contentsOf: newQueryItems)
        }
        urlComponents?.queryItems = existingQueryItems.isEmpty ? nil : existingQueryItems

        guard let url = urlComponents?.url else {
            logger.error("Failed to construct URL for path: \(path)")
            throw AppError(network: .invalidURL)
        }
        logger.debug("Constructed endpoint URL: \(url.absoluteString)")
        return url
    }

    // MARK: - Generic API Request Methods

    /// Performs a GET request to an endpoint and decodes the response.
    func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem]? = nil, responseType: T.Type, timeoutInterval: TimeInterval? = nil) async throws -> T {
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = try await endpointURL(endpoint, queryItems: queryItems)
        let request = try sessionManager.buildRequest(url: url, method: HTTPMethod.get.rawValue, accessToken: accessToken)
        return try await sessionManager.performRequest(request: request, responseType: responseType, timeoutInterval: timeoutInterval)
    }

    /// Performs a POST request to an endpoint with a body and decodes the response.
    func post<T: Decodable>(endpoint: String, body: [String: String]? = nil, contentType: String = "application/json", responseType: T.Type, timeoutInterval: TimeInterval? = nil) async throws -> T {
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = try await endpointURL(endpoint)
        let request = try sessionManager.buildRequest(url: url, method: HTTPMethod.post.rawValue, body: body, contentType: contentType, accessToken: accessToken)
        return try await sessionManager.performRequest(request: request, responseType: responseType, timeoutInterval: timeoutInterval)
    }

    /// Performs a POST request and attempts to optionally decode the response (e.g., for like/repost actions).
    func postOptional<T: Decodable>(endpoint: String, body: [String: String]? = nil, contentType: String = "application/json", responseType: T.Type, timeoutInterval: TimeInterval? = nil) async throws -> T? {
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = try await endpointURL(endpoint)
        let request = try sessionManager.buildRequest(url: url, method: HTTPMethod.post.rawValue, body: body, contentType: contentType, accessToken: accessToken)
        // Use performRequestOptional which returns nil on decoding failure/empty body
        return try await sessionManager.performRequestOptional(request: request, responseType: responseType, timeoutInterval: timeoutInterval)
    }

    // Add PATCH, PUT, DELETE methods similarly if needed

    /// Performs a PATCH request (e.g., for updating profile).
    func patch<T: Decodable>(endpoint: String, body: [String: String]? = nil, contentType: String = "application/x-www-form-urlencoded", responseType: T.Type, timeoutInterval: TimeInterval? = nil) async throws -> T {
        guard let accessToken = await fetchAccessToken() else {
            throw AppError(mastodon: .missingCredentials)
        }
        let url = try await endpointURL(endpoint)
        // Note: Profile updates often use form-urlencoded
        let request = try sessionManager.buildRequest(url: url, method: HTTPMethod.patch.rawValue, body: body, contentType: contentType, accessToken: accessToken)
        return try await sessionManager.performRequest(request: request, responseType: responseType, timeoutInterval: timeoutInterval)
    }

    // MARK: - Specific Mastodon API Endpoints

    // --- Timeline ---
    func fetchHomeTimeline(maxId: String? = nil, minId: String? = nil, limit: Int? = nil, timeoutInterval: TimeInterval? = 60.0) async throws -> [Post] {
        var query: [URLQueryItem] = []
        if let maxId = maxId { query.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let minId = minId { query.append(URLQueryItem(name: "min_id", value: minId)) }
        if let limit = limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }

        return try await get(endpoint: "/api/v1/timelines/home", queryItems: query.isEmpty ? nil : query, responseType: [Post].self, timeoutInterval: timeoutInterval)
    }

    // --- Statuses (Posts) ---
    // Updated to match MastodonAPIServiceProtocol
    func postStatus(status: String, visibility: PostVisibility, inReplyToId: String? = nil) async throws -> Post {
        var body: [String: String] = [
            "status": status,
            "visibility": visibility.rawValue // Add visibility to the request body
        ]
        if let replyId = inReplyToId {
            body["in_reply_to_id"] = replyId
        }
        // Add other parameters to body dictionary as needed (e.g., media_ids)
        return try await post(endpoint: "/api/v1/statuses", body: body, responseType: Post.self)
    }

    func fetchPostContext(postId: String) async throws -> PostContext {
        let endpoint = "/api/v1/statuses/\(postId)/context"
        return try await get(endpoint: endpoint, responseType: PostContext.self)
    }

    func favouritePost(postId: String) async throws -> Post? {
        let endpoint = "/api/v1/statuses/\(postId)/favourite"
        // Use postOptional as the response might be the updated Post or just status 200
        return try await postOptional(endpoint: endpoint, responseType: Post.self)
    }

    func unfavouritePost(postId: String) async throws -> Post? {
        let endpoint = "/api/v1/statuses/\(postId)/unfavourite"
        return try await postOptional(endpoint: endpoint, responseType: Post.self)
    }

    func reblogPost(postId: String) async throws -> Post? {
        let endpoint = "/api/v1/statuses/\(postId)/reblog"
        return try await postOptional(endpoint: endpoint, responseType: Post.self)
    }

    func unreblogPost(postId: String) async throws -> Post? {
        let endpoint = "/api/v1/statuses/\(postId)/unreblog"
        return try await postOptional(endpoint: endpoint, responseType: Post.self)
    }

    // --- Accounts ---
    func fetchCurrentUser() async throws -> User {
        let endpoint = "/api/v1/accounts/verify_credentials"
        return try await get(endpoint: endpoint, responseType: User.self)
    }

    func fetchAccount(id: String) async throws -> Account {
        let endpoint = "/api/v1/accounts/\(id)"
        return try await get(endpoint: endpoint, responseType: Account.self)
    }

    func fetchAccountStatuses(accountId: String, onlyMedia: Bool? = nil, excludeReplies: Bool? = nil /* add other filters */) async throws -> [Post] {
        let endpoint = "/api/v1/accounts/\(accountId)/statuses"
        var query: [URLQueryItem] = []
        if let onlyMedia = onlyMedia { query.append(URLQueryItem(name: "only_media", value: String(onlyMedia))) }
        if let excludeReplies = excludeReplies { query.append(URLQueryItem(name: "exclude_replies", value: String(excludeReplies))) }
        // Add other query params

        return try await get(endpoint: endpoint, queryItems: query.isEmpty ? nil : query, responseType: [Post].self)
    }

    func fetchAccountFollowers(accountId: String) async throws -> [User] { // Should return User array based on ProfileViewModel
        let endpoint = "/api/v1/accounts/\(accountId)/followers"
        return try await get(endpoint: endpoint, responseType: [User].self)
    }

    func fetchAccountFollowing(accountId: String) async throws -> [User] { // Should return User array
        let endpoint = "/api/v1/accounts/\(accountId)/following"
        return try await get(endpoint: endpoint, responseType: [User].self)
    }

    func WorkspaceUserMediaPosts(accountID: String, onlyMedia: Bool = true, maxId: String? = nil) async throws -> [Post] {
        let endpoint = "/api/v1/accounts/\(accountID)/statuses"
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "only_media", value: String(onlyMedia)))

        if let maxId = maxId {
            queryItems.append(URLQueryItem(name: "max_id", value: maxId))
        }
        
        // Consider adding a default limit or making it a parameter
        // queryItems.append(URLQueryItem(name: "limit", value: "20")) // Example limit

        return try await get(endpoint: endpoint, queryItems: queryItems.isEmpty ? nil : queryItems, responseType: [Post].self)
    }

    // Example: Update profile requires PATCH and often form-urlencoded data
    func updateCurrentUserProfile(fields: [String: String]) async throws -> User {
        let endpoint = "/api/v1/accounts/update_credentials"
        // Using the patch method defined earlier
        return try await patch(endpoint: endpoint, body: fields, contentType: "application/x-www-form-urlencoded", responseType: User.self)
    }

    // --- Search ---
    func search(query: String, type: String? = nil, limit: Int? = nil, resolve: Bool? = nil, excludeUnreviewed: Bool? = nil, accountId: String? = nil, maxId: String? = nil, minId: String? = nil, offset: Int? = nil) async throws -> SearchResults {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
        if let type = type { queryItems.append(URLQueryItem(name: "type", value: type)) }
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let resolve = resolve { queryItems.append(URLQueryItem(name: "resolve", value: String(resolve))) }
        if let exclude = excludeUnreviewed { queryItems.append(URLQueryItem(name: "exclude_unreviewed", value: String(exclude))) }
        if let accountId = accountId { queryItems.append(URLQueryItem(name: "account_id", value: accountId)) }
        if let maxId = maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let minId = minId { queryItems.append(URLQueryItem(name: "min_id", value: minId)) }
        if let offset = offset { queryItems.append(URLQueryItem(name: "offset", value: String(offset))) }

        // Use V2 search endpoint
        return try await get(endpoint: "/api/v2/search", queryItems: queryItems, responseType: SearchResults.self)
    }

    // --- Trends ---
    func fetchTrendingTags() async throws -> [Tag] {
        let endpoint = "/api/v1/trends/tags"
        return try await get(endpoint: endpoint, responseType: [Tag].self)
    }

    func fetchTrendingStatuses() async throws -> [Post] {
        let endpoint = "/api/v1/trends/statuses"
        return try await get(endpoint: endpoint, responseType: [Post].self)
    }

    func fetchHashtagTimeline(hashtag: String) async throws -> [Post] {
        guard let encodedHashtag = hashtag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AppError(message: "Invalid hashtag encoding")
        }
        let endpoint = "/api/v1/timelines/tag/\(encodedHashtag)"
        return try await get(endpoint: endpoint, responseType: [Post].self)
    }

    // --- OAuth ---
    /// Registers the app with a Mastodon instance. Note: This doesn't require authentication token.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        let body: [String: String] = [
            "client_name": "Mustard",
            "redirect_uris": "mustard://oauth-callback",
            "scopes": "read write follow push",
            "website": "https://example.com" // Replace with your app's website
        ]

        let endpointURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: endpointURL) // Build request manually as no token is needed
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logger.info("Sending OAuth app registration request to \(endpointURL.absoluteString)")

        // Use sessionManager to perform the unauthenticated request
        let registerResponse: RegisterResponse = try await sessionManager.performRequest(request: request, responseType: RegisterResponse.self)

        logger.info("Successfully registered OAuth app. Client ID: \(registerResponse.clientId)")
        return OAuthConfig(
            clientId: registerResponse.clientId,
            clientSecret: registerResponse.clientSecret,
            redirectUri: registerResponse.redirectUri,
            scope: "read write follow push" // Use the requested scope
        )
    }

    // Token exchange is handled in AuthenticationService as it involves specific OAuth logic.
}
