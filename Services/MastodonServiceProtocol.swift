//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

@MainActor
/// OAuth Configuration Details
struct OAuthConfig: Decodable {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let scope: String
}

extension OAuthConfig: Sendable {}

/// Represents the response received after successful registration.
struct RegisterResponse: Codable {
    let client_id: String
    let client_secret: String
    // No 'access_token' or 'account' here, since we only get those after exchanging the code
}

extension RegisterResponse: Sendable {}

/// Represents the response received after obtaining an access token.
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let scope: String
    let created_at: Int
    
    /// Convenience property to access `access_token`.
    var accessToken: String { access_token }
}

extension TokenResponse: Sendable {}

/// Defines all required methods & properties for interacting with a Mastodon-like backend.
@MainActor
protocol MastodonServiceProtocol: AnyObject {
    
    // MARK: - Core Properties
    
    /// Base URL of the Mastodon instance (e.g., `https://mastodon.social`).
    var baseURL: URL? { get set }
    
    /// Access token used for authenticated requests.
    var accessToken: String? { get set }
    
    // MARK: - Initialization Methods
    
    /// Ensures that the service is fully initialized, e.g., loading necessary configurations or credentials.
    func ensureInitialized() async throws
    
    // MARK: - Timeline Methods

    func fetchTimeline(useCache: Bool) async throws -> [Post]
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post]
    func clearTimelineCache() async throws
    func loadTimelineFromDisk() async throws -> [Post]
    func saveTimelineToDisk(_ posts: [Post]) async throws
    func backgroundRefreshTimeline() async

    // MARK: - User Methods
    
    /// Fetches the current authenticated user.
    /// - Returns: A `User` object representing the current user.
    func fetchCurrentUser() async throws -> User

    // MARK: - Authentication Methods
    
    func validateToken() async throws
    func saveAccessToken(_ token: String) async throws
    func clearAccessToken() async throws
    func retrieveAccessToken() async throws -> String?
    func retrieveInstanceURL() async throws -> URL?
    
    // MARK: - Post Actions
    
    func toggleLike(postID: String) async throws
    func toggleRepost(postID: String) async throws
    func comment(postID: String, content: String) async throws
    
    // MARK: - Simplified OAuth Methods
    
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws
    
    // MARK: - Streaming Methods
    
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error>
    
    // MARK: - Top Posts Methods
    
    func fetchTrendingPosts() async throws -> [Post]
}
