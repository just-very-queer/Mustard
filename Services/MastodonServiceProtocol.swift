//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

@MainActor
/// OAuth Configuration Details
struct OAuthConfig {
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
    
    // MARK: - Timeline Methods

    /// Fetches the user's home timeline.
    /// - Parameter useCache: Whether to use a cached version if available.
    /// - Returns: An array of `Post` objects representing the timeline.
    func fetchTimeline(useCache: Bool) async throws -> [Post]
    
    /// Fetches a specific page of the timeline (pagination).
    /// - Parameters:
    ///   - page: The page number to fetch.
    ///   - useCache: Whether to use a cached version if available.
    /// - Returns: An array of `Post` objects for that page.
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post]
    
    /// Clears any in-memory or on-disk cache of timeline data.
    func clearTimelineCache() async throws
    
    /// Loads timeline data from disk cache, if present.
    /// - Returns: Cached `Post` objects (could be empty if none).
    func loadTimelineFromDisk() async throws -> [Post]
    
    /// Saves the provided timeline to disk cache.
    /// - Parameter posts: The posts to save.
    func saveTimelineToDisk(_ posts: [Post]) async throws
    
    /// Performs a background refresh of the timeline (e.g., silent reload).
    func backgroundRefreshTimeline() async
    
    // MARK: - Authentication Methods
    
    /// Validates the currently stored token on the Mastodon server.
    /// - Throws: An error if the token is invalid, missing, or if the server check fails.
    func validateToken() async throws
    
    /// Saves the given access token securely (e.g., Keychain).
    /// - Parameter token: The token to save.
    func saveAccessToken(_ token: String) async throws
    
    /// Clears the stored access token (in memory & Keychain).
    func clearAccessToken() async throws
    
    /// Retrieves the current access token from memory/Keychain if any.
    /// - Returns: The stored access token, if present.
    func retrieveAccessToken() async throws -> String?
    
    /// Retrieves the stored instance URL from Keychain.
    /// - Returns: The instance URL, if present.
    func retrieveInstanceURL() async throws -> URL?
    
    // MARK: - Post Actions
    
    /// Toggles the "favorite" (like) status of a post.
    /// - Parameter postID: The post to like/unlike.
    func toggleLike(postID: String) async throws
    
    /// Toggles the "reblog" (repost) status of a post.
    /// - Parameter postID: The post to repost/un-repost.
    func toggleRepost(postID: String) async throws
    
    /// Submits a comment (reply) to an existing post.
    /// - Parameters:
    ///   - postID: ID of the post to reply to.
    ///   - content: Body text of the comment.
    func comment(postID: String, content: String) async throws
    
    // MARK: - Simplified OAuth Methods
    
    /// Registers the OAuth application with the Mastodon instance (obtaining `client_id` & `client_secret`).
    /// - Parameter instanceURL: The Mastodon instance URL.
    /// - Returns: An `OAuthConfig` with the necessary credentials & scope.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig
    
    /// Exchanges an authorization code for an access token.
    /// - Parameters:
    ///   - code: The authorization code from OAuth callback.
    ///   - config: The `OAuthConfig` (clientID, secret, etc.).
    ///   - instanceURL: The same instance URL used for registration.
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws
    
    // MARK: - Streaming Methods
    
    /// Streams the timeline for real-time updates.
    /// - Returns: An async sequence of `Post` objects.
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error>
    
    // MARK: - Top Posts Methods
    
    /// Fetches the top Mastodon posts of the day.
    /// - Returns: An array of `Post` objects representing top posts.
    func fetchTrendingPosts() async throws -> [Post]
}
