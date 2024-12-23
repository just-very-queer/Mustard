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
    var baseURL: URL? { get set }
    
    func fetchHomeTimeline() async throws -> [Post]
    func fetchPosts(keyword: String) async throws -> [Post]
    
    func likePost(postID: String) async throws -> Post
    func unlikePost(postID: String) async throws -> Post
    
    func repost(postID: String) async throws -> Post
    func undoRepost(postID: String) async throws -> Post
    
    func comment(postID: String, content: String) async throws -> Post
}

