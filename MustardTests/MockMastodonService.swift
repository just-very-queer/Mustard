//
//  MockMastodonService.swift
//  MustardTests
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
@testable import Mustard

@MainActor
class MockMastodonService: MastodonServiceProtocol {
    var baseURL: URL?
    
    var shouldSucceed: Bool
    var samplePosts: [Post] = []
    var errorMessage: String
    
    init(shouldSucceed: Bool = true,
         samplePosts: [Post] = [],
         errorMessage: String = "Mock service error.") {
        self.shouldSucceed = shouldSucceed
        self.samplePosts = samplePosts
        self.errorMessage = errorMessage
    }
    
    func fetchHomeTimeline() async throws -> [Post] {
        if shouldSucceed {
            if samplePosts.isEmpty {
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
        if shouldSucceed { return samplePosts }
        throw MustardAppError(message: errorMessage)
    }
    
    func likePost(postID: String) async throws -> Post {
        if shouldSucceed {
            // Return some updated post
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock liked post</p>",
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
            throw MustardAppError(message: errorMessage)
        }
    }
    
    func unlikePost(postID: String) async throws -> Post {
        if shouldSucceed {
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock unliked post</p>",
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
            throw MustardAppError(message: errorMessage)
        }
    }
    
    func repost(postID: String) async throws -> Post {
        if shouldSucceed {
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock repost</p>",
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
            throw MustardAppError(message: errorMessage)
        }
    }
    
    func undoRepost(postID: String) async throws -> Post {
        if shouldSucceed {
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock undone repost</p>",
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
            throw MustardAppError(message: errorMessage)
        }
    }
    
    func comment(postID: String, content: String) async throws -> Post {
        if shouldSucceed {
            let sampleAccount = Account(
                id: "a1",
                username: "mockuser1",
                displayName: "Mock User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "mockuser1"
            )
            return Post(
                id: postID,
                content: "<p>Mock comment: \(content)</p>",
                createdAt: Date(),
                account: sampleAccount,
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 1
            )
        } else {
            throw MustardAppError(message: errorMessage)
        }
    }
}

