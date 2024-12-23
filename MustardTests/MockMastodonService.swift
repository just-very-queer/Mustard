//
//  MockMastodonService.swift
//  MustardTests
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
@testable import Mustard

/// Mock service conforming to `MastodonServiceProtocol` for testing purposes.
@MainActor
class MockMastodonService: MastodonServiceProtocol {
    var baseURL: URL?
    
    var shouldSucceed: Bool
    var samplePosts: [Post] = []
    var errorMessage: String = "Mock service error."
    
    /// Initializes the mock service.
    /// - Parameters:
    ///   - shouldSucceed: Determines if the service should simulate a successful response.
    ///   - samplePosts: Optional sample posts to return on success.
    ///   - errorMessage: Optional error message to return on failure.
    init(shouldSucceed: Bool = true, samplePosts: [Post] = [], errorMessage: String = "Mock service error.") {
        self.shouldSucceed = shouldSucceed
        self.samplePosts = samplePosts
        self.errorMessage = errorMessage
    }
    
    func fetchHomeTimeline() async throws -> [Post] {
        if shouldSucceed {
            if samplePosts.isEmpty {
                // Return a default sample post if none are provided
                let sampleAccount = Account(
                    id: "a1",
                    username: "mockuser1",
                    displayName: "Mock User 1",
                    avatar: URL(string: "https://example.com/avatar1.png")!,
                    acct: "mockuser1"
                )
                let samplePost = Post(
                    id: "1",
                    content: "<p>Mock Home Post</p>",
                    createdAt: Date(),
                    account: sampleAccount,
                    mediaAttachments: [],
                    isFavourited: false,
                    isReblogged: false,
                    reblogsCount: 0,
                    favouritesCount: 0,
                    repliesCount: 0
                )
                return [samplePost]
            } else {
                return samplePosts
            }
        } else {
            throw MustardAppError(message: errorMessage)
        }
    }
    
    func fetchPosts(keyword: String) async throws -> [Post] {
        if shouldSucceed {
            // Return sample posts based on the keyword
            let sampleAccount = Account(
                id: "a2",
                username: "mockuser2",
                displayName: "Mock User 2",
                avatar: URL(string: "https://example.com/avatar2.png")!,
                acct: "mockuser2"
            )
            let samplePost = Post(
                id: "2",
                content: "<p>Mock Tag Post for #\(keyword)</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
            return [samplePost]
        } else {
            throw MustardAppError(message: "Mock fetch posts failed for keyword: \(keyword).")
        }
    }
    
    func likePost(postID: String) async throws -> Post {
        if shouldSucceed {
            // Return a mock updated post indicating it's been liked
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock Liked Post</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: true,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 1,
                repliesCount: 0
            )
        } else {
            throw MustardAppError(message: "Mock like post failed for postID: \(postID).")
        }
    }
    
    func unlikePost(postID: String) async throws -> Post {
        if shouldSucceed {
            // Return a mock updated post indicating it's been unliked
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock Unliked Post</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
        } else {
            throw MustardAppError(message: "Mock unlike post failed for postID: \(postID).")
        }
    }
    
    func repost(postID: String) async throws -> Post {
        if shouldSucceed {
            // Return a mock updated post indicating it's been reposted
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock Reposted Post</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: true,
                reblogsCount: 1,
                favouritesCount: 0,
                repliesCount: 0
            )
        } else {
            throw MustardAppError(message: "Mock repost failed for postID: \(postID).")
        }
    }
    
    func undoRepost(postID: String) async throws -> Post {
        if shouldSucceed {
            // Return a mock updated post indicating the repost has been undone
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock Undoreposted Post</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
        } else {
            throw MustardAppError(message: "Mock undo repost failed for postID: \(postID).")
        }
    }
    
    func comment(postID: String, content: String) async throws -> Post {
        if shouldSucceed {
            // Return a mock comment post
            let sampleAccount = Account(
                id: "a3",
                username: "commentuser",
                displayName: "Comment User",
                avatar: URL(string: "https://example.com/avatar3.png")!,
                acct: "commentuser"
            )
            return Post(
                id: "c1",
                content: content,
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
        } else {
            throw MustardAppError(message: "Mock comment failed for postID: \(postID).")
        }
    }
}
