//
//  PreviewService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
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
    
    func fetchTimeline() async throws -> [Post] {
        return mockPosts
    }
    
    func toggleLike(postID: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isFavourited.toggle()
            mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
        }
    }
    
    func toggleRepost(postID: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isReblogged.toggle()
            mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
        }
    }
    
    func comment(postID: String, content: String) async throws {
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].repliesCount += 1
        }
    }
    
    func saveAccessToken(_ token: String) throws {
        self.accessToken = token
    }
    
    func clearAccessToken() throws {
        self.accessToken = nil
    }
    
    func fetchAccounts() async throws -> [Account] {
        return mockAccounts
    }
    
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if mockAccounts.contains(where: { $0.username.lowercased() == username.lowercased() }) {
            throw MockError.usernameAlreadyExists
        }
        
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
    
    func authenticate(username: String, password: String, instanceURL: URL) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if username.isEmpty || password.isEmpty {
            throw MockError.invalidCredentials
        }
        
        self.accessToken = "authenticatedMockAccessToken123"
        self.baseURL = instanceURL
        
        return self.accessToken!
    }
    
    func retrieveAccessToken() throws -> String? {
        return accessToken
    }
    
    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }
    
    // MARK: - Mock Errors
    
    enum MockError: LocalizedError {
        case postNotFound
        case usernameAlreadyExists
        case invalidCredentials
        
        var errorDescription: String? {
            switch self {
            case .postNotFound: return "The specified post was not found."
            case .usernameAlreadyExists: return "The username is already taken."
            case .invalidCredentials: return "Invalid username or password."
            }
        }
    }
}

