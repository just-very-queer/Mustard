//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

@MainActor
/// OAuth Configuration Details
struct OAuthConfig: Sendable {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let scope: String
}

/// Represents the response received after successful registration.
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


/// Represents the response received after obtaining an access token.
struct TokenResponse: Codable, Sendable {
    let access_token: String
    let token_type: String
    let scope: String
    let created_at: Int
    
    /// Convenience property to access `access_token`.
    var accessToken: String { access_token }
}

/// Defines all required methods & properties for interacting with a Mastodon-like backend.
@MainActor
protocol MastodonServiceProtocol: AnyObject {
    
    func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String

    
    // MARK: - Core Properties
    
    /// The base URL of the Mastodon instance to connect to (e.g., `https://mastodon.social`).
    var baseURL: URL? { get set }
    
    /// The OAuth access token used to authenticate API requests for a specific user.
    var accessToken: String? { get set }
    
    // MARK: - Initialization
    
    /// Ensures that the service is properly initialized and ready to make API calls.
    ///
    /// This might involve:
    /// - Loading the `baseURL` and `accessToken` from secure storage (e.g., Keychain).
    /// - Validating that the `baseURL` and `accessToken` are present and valid.
    /// - Setting up any necessary internal state.
    ///
    /// - Throws: An `AppError` if initialization fails (e.g., missing credentials).
    func ensureInitialized() async throws
    
    // MARK: - Authentication
    
    /// Checks if the service has valid credentials to make authenticated API requests.
    ///
    /// - Returns: `true` if authenticated, `false` otherwise.
    /// - Throws: An `AppError` if there's an issue determining authentication status.
    func isAuthenticated() async throws -> Bool
    
    /// Fetches the currently authenticated user's profile information.
    ///
    /// - Returns: A `User` object representing the current user.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func fetchCurrentUser() async throws -> User

    /// Validates the current access token with the Mastodon server.
    ///
    /// This is typically used to check if the token is still valid after the app has been in the background or if there's any doubt about its validity.
    /// - Throws: An `AppError` if the token is invalid or the request fails.
    func validateToken() async throws

    /// Saves the provided access token securely, allowing the service to make authenticated requests.
    ///
    /// - Parameter token: The OAuth access token to save.
    /// - Throws: An `AppError` if saving the token fails.
    func saveAccessToken(_ token: String) async throws

    /// Clears the stored access token, effectively logging the user out.
    ///
    /// - Throws: An `AppError` if clearing the token fails.
    func clearAccessToken() async throws

    /// Retrieves the stored access token.
    ///
    /// - Returns: The stored access token, or `nil` if no token is found.
    /// - Throws: An `AppError` if retrieving the token fails.
    func retrieveAccessToken() async throws -> String?

    /// Retrieves the stored instance URL.
    ///
    /// - Returns: The stored instance URL, or `nil` if no URL is found.
    /// - Throws: An `AppError` if retrieving the URL fails.
    func retrieveInstanceURL() async throws -> URL?
    
    // MARK: - Timeline
    
    /// Fetches the user's home timeline from the Mastodon server.
    ///
    /// - Parameter useCache: Whether to use a cached version of the timeline if available.
    /// - Returns: An array of `Post` objects representing the timeline.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func fetchTimeline(useCache: Bool) async throws -> [Post]

    /// Fetches a specific page of the user's home timeline.
    ///
    /// - Parameters:
    ///   - page: The page number to fetch (usually for infinite scrolling).
    ///   - useCache: Whether to use a cached version of the timeline if available.
    /// - Returns: An array of `Post` objects representing the requested page of the timeline.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post]

    /// Clears any cached timeline data.
    func clearTimelineCache()

    /// Loads a previously saved timeline from disk (if available).
    ///
    /// - Returns: An array of `Post` objects representing the loaded timeline, or an empty array if no saved timeline is found.
    /// - Throws: An `AppError` if loading the timeline fails.
    func loadTimelineFromDisk() async throws -> [Post]

    /// Saves the given timeline to disk for later retrieval.
    ///
    /// - Parameter posts: The array of `Post` objects to save.
    /// - Throws: An `AppError` if saving the timeline fails.
    func saveTimelineToDisk(_ posts: [Post]) async throws

    /// Refreshes the timeline in the background, typically used when a cached version is displayed initially.
    ///
    /// This allows the app to show cached data quickly while fetching the latest data in the background.
    func backgroundRefreshTimeline() async

    /// Fetches trending posts from the Mastodon server.
    ///
    /// - Returns: An array of `Post` objects representing the trending posts.
    /// - Throws: An `AppError` if the request fails.
    func fetchTrendingPosts() async throws -> [Post]
    
    // MARK: - Post Actions
    
    /// Toggles the "like" status of a post.
    ///
    /// - Parameter postID: The ID of the post to like or unlike.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func toggleLike(postID: String) async throws

    /// Toggles the "repost" status of a post.
    ///
    /// - Parameter postID: The ID of the post to repost or unrepost.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func toggleRepost(postID: String) async throws

    /// Posts a comment on a given post.
    ///
    /// - Parameters:
    ///   - postID: The ID of the post to comment on.
    ///   - content: The text content of the comment.
    /// - Throws: An `AppError` if the request fails or the user is not authenticated.
    func comment(postID: String, content: String) async throws
    
    // MARK: - OAuth
    
    /// Registers the application with a Mastodon instance to obtain OAuth client credentials.
    ///
    /// - Parameter instanceURL: The URL of the Mastodon instance to register with.
    /// - Returns: An `OAuthConfig` containing the client ID and secret.
    /// - Throws: An `AppError` if registration fails.
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig

    /// Exchanges an authorization code for an access token.
    ///
    /// - Parameters:
    ///   - code: The authorization code obtained from the Mastodon server.
    ///   - config: The `OAuthConfig` for the application.
    ///   - instanceURL: The URL of the Mastodon instance.
    /// - Throws: An `AppError` if the exchange fails.
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws

    // MARK: - Streaming
    
    /// Establishes a real-time stream of updates from the Mastodon timeline.
    ///
    /// - Returns: An `AsyncThrowingStream` that yields `Post` objects as they are received.
    /// - Throws: An `AppError` if the stream cannot be established or if there's an error during streaming.
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error>
    
    /// Determines whether the current access token is near expiry.
        ///
        /// - Returns: `true` if the token is near expiry or if the creation date is unknown, `false` otherwise.
        func isTokenNearExpiry() -> Bool

        /// Reauthenticates the user, obtaining a new access token.
        ///
        /// - Parameters:
        ///   - config: The `OAuthConfig` for the application.
        ///   - instanceURL: The URL of the Mastodon instance.
        /// - Throws: An `AppError` if reauthentication fails.
        func reauthenticate(config: OAuthConfig, instanceURL: URL) async throws
    /// Clears all keychain data for the current user session.
        ///
    /// - Throws: An `AppError` if the keychain clearing process fails.
    func clearAllKeychainData() async throws
}
