//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by Your Name on [Date].
//

import Foundation

/// Protocol defining the required methods for interacting with a Mastodon-like backend service.
protocol MastodonServiceProtocol {
    /// The base URL of the Mastodon instance.
    var baseURL: URL? { get set }
    
    /// The access token for authenticated requests.
    var accessToken: String? { get set }
    
    // MARK: - Timeline Methods
    
    /// Fetches the user's home timeline (cached if possible).
    /// - Parameter useCache: Whether to use a cached version if available.
    /// - Returns: An array of `Post` objects.
    func fetchTimeline(useCache: Bool) async throws -> [Post]
    
    /// Clears any in-memory or on-disk cache of timeline data.
    func clearTimelineCache()
    
    // MARK: - Authentication Methods
    
    /// Saves the access token securely.
    func saveAccessToken(_ token: String) throws
    
    /// Clears the stored access token.
    func clearAccessToken() throws
    
    /// Retrieves the stored access token.
    func retrieveAccessToken() throws -> String?
    
    /// Retrieves the stored instance URL (if you’re persisting it).
    func retrieveInstanceURL() throws -> URL?
    
    // MARK: - Additional Methods (Like, Repost, Comment)
    
    /// Toggles the "favorite" status (like) of a post.
    func toggleLike(postID: String) async throws
    
    /// Toggles the repost (reblog) status of a post.
    func toggleRepost(postID: String) async throws
    
    /// Comments on a specific post.
    func comment(postID: String, content: String) async throws
    
    // MARK: - Register Account
    /// Registers a new account. (Placeholder or real Mastodon endpoint)
    /// - Parameters:
    ///   - username: The username.
    ///   - password: The password.
    ///   - instanceURL: The Mastodon instance URL.
    /// - Returns: The newly created Account.
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account
}

