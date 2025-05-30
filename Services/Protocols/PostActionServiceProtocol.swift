//
//  PostActionServiceProtocol.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//


import Foundation

// Protocol defining post action methods used by TimelineViewModel
protocol PostActionServiceProtocol {
    /// Toggle like/unlike for a post by ID.
    /// - Parameter postID: The unique identifier of the post.
    /// - Returns: The updated Post object, or nil if not available.
    func toggleLike(postID: String) async throws -> Post?
    
    /// Toggle repost/unrepost for a post by ID.
    /// - Parameter postID: The unique identifier of the post.
    /// - Returns: The updated Post object, or nil if not available.
    func toggleRepost(postID: String) async throws -> Post?
    
    /// Comment on a post.
    /// - Parameters:
    ///   - postID: The unique identifier of the post to comment on.
    ///   - content: The text content of the comment.
    /// - Returns: The newly created comment as a Post object, or nil.
    func comment(postID: String, content: String) async throws -> Post?
    
    // Add other post action methods as needed, for example:
    // func deletePost(postID: String) async throws -> Bool
    // func fetchComments(postID: String) async throws -> [Post]
}
