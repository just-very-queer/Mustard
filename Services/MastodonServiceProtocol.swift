//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// Protocol defining the required methods and properties for interacting with a Mastodon-like backend service.
protocol MastodonServiceProtocol {
    // MARK: - Properties

    /// The base URL of the Mastodon instance.
    var baseURL: URL? { get set }

    /// The access token for authenticated requests.
    var accessToken: String? { get set }

    // MARK: - Timeline Methods

    /// Fetches the user's home timeline.
    ///
    /// - Parameter useCache: Whether to use a cached version if available.
    /// - Returns: An array of `Post` objects representing the timeline.
    func fetchTimeline(useCache: Bool) async throws -> [Post]

    /// Clears any in-memory or on-disk cache of timeline data.
    func clearTimelineCache()

    /// Loads the timeline from disk cache.
    ///
    /// - Returns: An array of cached `Post` objects.
    func loadTimelineFromDisk() -> [Post]

    /// Saves the provided timeline to disk cache.
    ///
    /// - Parameter posts: An array of `Post` objects to save.
    func saveTimelineToDisk(_ posts: [Post])

    /// Performs a background refresh of the timeline.
    func backgroundRefreshTimeline() async

    // MARK: - Authentication Methods

    /// Validates the stored token with the Mastodon server.
    ///
    /// - Throws: An error if the token validation fails.
    func validateToken() async throws

    /// Saves the access token securely.
    ///
    /// - Parameter token: The access token to save.
    /// - Throws: An error if the token cannot be saved.
    func saveAccessToken(_ token: String) throws

    /// Clears the stored access token.
    ///
    /// - Throws: An error if the access token cannot be cleared.
    func clearAccessToken() throws

    /// Retrieves the stored access token.
    ///
    /// - Returns: The access token, if available.
    /// - Throws: An error if the access token cannot be retrieved.
    func retrieveAccessToken() throws -> String?

    /// Retrieves the stored instance URL.
    ///
    /// - Returns: The instance URL, if available.
    /// - Throws: An error if the instance URL cannot be retrieved.
    func retrieveInstanceURL() throws -> URL?

    // MARK: - Post Actions

    /// Toggles the "favorite" status (like) of a post.
    ///
    /// - Parameter postID: The ID of the post to like/unlike.
    /// - Throws: An error if the action fails.
    func toggleLike(postID: String) async throws

    /// Toggles the repost (reblog) status of a post.
    ///
    /// - Parameter postID: The ID of the post to repost/un-repost.
    /// - Throws: An error if the action fails.
    func toggleRepost(postID: String) async throws

    /// Comments on a specific post.
    ///
    /// - Parameters:
    ///   - postID: The ID of the post to comment on.
    ///   - content: The content of the comment.
    /// - Throws: An error if the comment action fails.
    func comment(postID: String, content: String) async throws

    // MARK: - OAuth Methods

    /// Registers the OAuth application with the Mastodon instance.
    ///
    /// - Parameter instanceURL: The Mastodon instance URL.
    /// - Returns: The OAuth configuration details.
    /// - Throws: An error if the registration fails.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig

    /// Initiates the OAuth authentication flow.
    ///
    /// - Parameters:
    ///   - instanceURL: The Mastodon instance URL.
    ///   - config: The OAuth configuration details.
    /// - Returns: The authorization code obtained after successful authentication.
    /// - Throws: An error if the authentication fails.
    func authenticateOAuth(instanceURL: URL, config: OAuthConfig) async throws -> String

    /// Exchanges the authorization code for an access token.
    ///
    /// - Parameters:
    ///   - code: The authorization code received from OAuth.
    ///   - config: The OAuth configuration.
    ///   - instanceURL: The Mastodon instance URL.
    /// - Throws: An error if the exchange fails.
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws
}

