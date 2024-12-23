//
//  MastodonServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Protocol defining the necessary methods and properties for interacting with the Mastodon service.
@MainActor
protocol MastodonServiceProtocol {
    /// The base URL of the Mastodon instance.
    var baseURL: URL? { get set }
    
    /// Fetches the home timeline posts.
    func fetchHomeTimeline() async throws -> [Post]
    
    /// Fetches posts based on a specific keyword (tag).
    /// - Parameter keyword: The hashtag to search for.
    /// - Returns: An array of `Post` objects.
    func fetchPosts(keyword: String) async throws -> [Post]
    
    /// Likes a specific post.
    /// - Parameter postID: The ID of the post to like.
    /// - Returns: The updated `Post` object.
    func likePost(postID: String) async throws -> Post
    
    /// Unlikes a specific post.
    /// - Parameter postID: The ID of the post to unlike.
    /// - Returns: The updated `Post` object.
    func unlikePost(postID: String) async throws -> Post
    
    /// Reblogs (reposts) a specific post.
    /// - Parameter postID: The ID of the post to reblog.
    /// - Returns: The updated `Post` object.
    func repost(postID: String) async throws -> Post
    
    /// Undoreblogs (removes the repost) of a specific post.
    /// - Parameter postID: The ID of the post to undoreblog.
    /// - Returns: The updated `Post` object.
    func undoRepost(postID: String) async throws -> Post
    
    /// Comments on a specific post.
    /// - Parameters:
    ///   - postID: The ID of the post to comment on.
    ///   - content: The content of the comment.
    /// - Returns: The newly created `Post` object representing the comment.
    func comment(postID: String, content: String) async throws -> Post
}
