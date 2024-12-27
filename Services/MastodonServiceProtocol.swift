//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Protocol defining the required methods for interacting with the Mastodon API.
protocol MastodonServiceProtocol {
    /// The base URL of the Mastodon instance.
    var baseURL: URL? { get set }
    
    /// The access token for authenticated requests.
    var accessToken: String? { get set }
    
    /// Fetches the user's home timeline.
    /// - Returns: An array of `Post` objects.
    func fetchTimeline() async throws -> [Post]
    
    /// Toggles the like status of a post.
    /// - Parameter postID: The identifier of the post.
    func toggleLike(postID: String) async throws
    
    /// Toggles the repost (reblog) status of a post.
    /// - Parameter postID: The identifier of the post.
    func toggleRepost(postID: String) async throws
    
    /// Adds a comment to a post.
    /// - Parameters:
    ///   - postID: The identifier of the post.
    ///   - content: The content of the comment.
    func comment(postID: String, content: String) async throws
    
    /// Saves the access token securely.
    /// - Parameter token: The access token string.
    func saveAccessToken(_ token: String) throws
    
    /// Clears the stored access token.
    func clearAccessToken() throws
    
    // MARK: - Additional Methods for Account Management
    
    /// Fetches the list of user accounts.
    /// - Returns: An array of `Account` objects.
    func fetchAccounts() async throws -> [Account]
    
    /// Registers a new account.
    /// - Parameters:
    ///   - username: The username for the new account.
    ///   - password: The password for the new account.
    ///   - instanceURL: The Mastodon instance URL.
    /// - Returns: The newly created `Account` object.
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account
    
    // MARK: - Additional Methods for Authentication
    
    /// Authenticates the user with provided credentials.
    /// - Parameters:
    ///   - username: The username.
    ///   - password: The password.
    ///   - instanceURL: The Mastodon instance URL.
    /// - Returns: The access token string.
    func authenticate(username: String, password: String, instanceURL: URL) async throws -> String
    
    /// Retrieves the stored access token.
    /// - Returns: The access token string.
    func retrieveAccessToken() throws -> String?
    
    /// Retrieves the stored instance URL.
    /// - Returns: The instance URL.
    func retrieveInstanceURL() throws -> URL?
}
