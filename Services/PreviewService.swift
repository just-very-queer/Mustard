//
//  PreviewService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// A mock service conforming to `MastodonServiceProtocol` for SwiftUI previews.
class PreviewService: MastodonServiceProtocol {
    
    // MARK: - Properties
    
    var baseURL: URL?
    var accessToken: String?
    
    // MARK: - Mock Data
    
    /// Sample accounts for preview.
    public lazy var sampleAccount1: Account = Account(
        id: "a1",
        username: "user1",
        displayName: "User One",
        avatar: URL(string: "https://example.com/avatar1.png")!,
        acct: "user1",
        instanceURL: URL(string: "https://mastodon.social")!,
        accessToken: "mockAccessToken123"
    )
    
    public lazy var sampleAccount2: Account = Account(
        id: "a2",
        username: "user2",
        displayName: "User Two",
        avatar: URL(string: "https://example.com/avatar2.png")!,
        acct: "user2",
        instanceURL: URL(string: "https://mastodon.social")!,
        accessToken: "mockAccessToken456"
    )
    
    /// Sample posts for preview.
    public lazy var samplePost1: Post = Post(
        id: "1",
        content: "<p>Hello, this is a sample post!</p>",
        createdAt: Date(),
        account: sampleAccount1,
        mediaAttachments: [],
        isFavourited: false,
        isReblogged: false,
        reblogsCount: 0,
        favouritesCount: 0,
        repliesCount: 0
    )
    
    public lazy var samplePost2: Post = Post(
        id: "2",
        content: "<p>Another example post with some <strong>bold</strong> text.</p>",
        createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
        account: sampleAccount2,
        mediaAttachments: [],
        isFavourited: true,
        isReblogged: false,
        reblogsCount: 1,
        favouritesCount: 5,
        repliesCount: 2
    )
    
    /// Mutable mock posts to allow state changes in previews.
    var mockPosts: [Post] = []
    
    /// Mock accounts list.
    var mockAccounts: [Account] = []
    
    // MARK: - Initializer
    
    /// Designated initializer
    init() {
        // Initialize with mock data
        self.baseURL = URL(string: "https://mastodon.social")
        self.accessToken = "mockAccessToken123"
        
        // By default, we add sample posts + accounts
        self.mockPosts = [samplePost1, samplePost2]
        self.mockAccounts = [sampleAccount1, sampleAccount2]
    }
    
    /// Convenience initializer to allow custom mockPosts and mockAccounts
    convenience init(mockPosts: [Post]? = nil, mockAccounts: [Account]? = nil) {
        self.init()
        if let mockPosts = mockPosts {
            self.mockPosts = mockPosts
        }
        if let mockAccounts = mockAccounts {
            self.mockAccounts = mockAccounts
        }
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    /// Fetch timeline; `useCache` is ignored in this mock; we always return `mockPosts`.
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        return mockPosts
    }
    
    /// Clears timeline by removing all mock posts.
    func clearTimelineCache() {
        mockPosts.removeAll()
    }
    
    /// Saves the access token in the mock. No real Keychain used here.
    func saveAccessToken(_ token: String) throws {
        self.accessToken = token
    }
    
    /// Clears the stored access token in the mock.
    func clearAccessToken() throws {
        self.accessToken = nil
    }
    
    /// Retrieves the stored access token (mock).
    func retrieveAccessToken() throws -> String? {
        return accessToken
    }
    
    /// Retrieves the stored instance URL (mock).
    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }
    
    /// Toggles like/favourite on a post.
    func toggleLike(postID: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isFavourited.toggle()
            mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
        }
    }
    
    /// Toggles repost/reblog on a post.
    func toggleRepost(postID: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isReblogged.toggle()
            mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
        }
    }
    
    /// Increments the replies count to simulate a comment.
    func comment(postID: String, content: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].repliesCount += 1
        }
    }
    
    /// Registers a new account (mock).
    func registerAccount(username: String,
                         password: String,
                         instanceURL: URL) async throws -> Account {
        // Simulate half-second delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // If username already taken, throw error
        if mockAccounts.contains(where: { $0.username.lowercased() == username.lowercased() }) {
            throw MockError.usernameAlreadyExists
        }
        
        // Create a new mock account
        let newAccount = Account(
            id: UUID().uuidString,
            username: username,
            displayName: username.capitalized,
            avatar: URL(string: "https://example.com/avatar_new.png")!,
            acct: username,
            instanceURL: instanceURL,
            accessToken: "newMockAccessToken123"
        )
        
        mockAccounts.append(newAccount)
        
        // Add a welcome post for the new user
        mockPosts.append(Post(
            id: UUID().uuidString,
            content: "<p>Welcome, \(username)!</p>",
            createdAt: Date(),
            account: newAccount,
            mediaAttachments: [],
            isFavourited: false,
            isReblogged: false,
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0
        ))
        
        return newAccount
    }
    
    // MARK: - Mock Errors
    
    enum MockError: LocalizedError {
        case usernameAlreadyExists
        case invalidCredentials
        
        var errorDescription: String? {
            switch self {
            case .usernameAlreadyExists:
                return "The username is already taken."
            case .invalidCredentials:
                return "Invalid username or password."
            }
        }
    }
    
    // MARK: - Additional (Optional) Methods
    
    /// If you have extra preview logic for accounts, keep them, or remove them if not used.
    /// For instance, a mock `authenticate(...)`, etc.
}
