//
//  MockMastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import Foundation

/// A mock service conforming to `MastodonServiceProtocol` for testing and previews.
class MockMastodonService: MastodonServiceProtocol {
    // MARK: - Properties
    
    var baseURL: URL?
    var accessToken: String?
    
    // MARK: - Mock Data
    
    /// Sample accounts for preview and testing.
    var mockAccounts: [Account] = []
    
    /// Sample posts for preview and testing.
    var mockPosts: [Post] = []
    
    /// Flag to control whether operations should succeed or fail (for testing error scenarios).
    var shouldSucceed: Bool
    
    // MARK: - Initializer
    
    /// Designated initializer with control over success/failure
    init(shouldSucceed: Bool = true,
         mockPosts: [Post]? = nil,
         mockAccounts: [Account]? = nil) {
        
        self.shouldSucceed = shouldSucceed
        self.mockPosts = mockPosts ?? []
        self.mockAccounts = mockAccounts ?? []
        
        // If no mock accounts provided, add default samples
        if self.mockAccounts.isEmpty {
            let sampleAccount1 = Account(
                id: "a1",
                username: "user1",
                displayName: "User One",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "user1",
                instanceURL: URL(string: "https://mastodon.social")!,
                accessToken: "mockAccessToken123"
            )
            
            let sampleAccount2 = Account(
                id: "a2",
                username: "user2",
                displayName: "User Two",
                avatar: URL(string: "https://example.com/avatar2.png")!,
                acct: "user2",
                instanceURL: URL(string: "https://mastodon.social")!,
                accessToken: "mockAccessToken456"
            )
            
            self.mockAccounts = [sampleAccount1, sampleAccount2]
        }
        
        // If no mock posts provided, add default samples
        if self.mockPosts.isEmpty, self.mockAccounts.count >= 2 {
            let samplePost1 = Post(
                id: "1",
                content: "<p>This is a mock post for preview purposes.</p>",
                createdAt: Date(),
                account: self.mockAccounts[0],
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
            
            let samplePost2 = Post(
                id: "2",
                content: "<p>Another example post with some <strong>bold</strong> text.</p>",
                createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
                account: self.mockAccounts[1],
                mediaAttachments: [],
                isFavourited: true,
                isReblogged: false,
                reblogsCount: 1,
                favouritesCount: 5,
                repliesCount: 2
            )
            
            self.mockPosts = [samplePost1, samplePost2]
        }
    }
    
    /// Convenience initializer (uses `shouldSucceed = true` by default).
    convenience init(mockPosts: [Post]? = nil, mockAccounts: [Account]? = nil) {
        self.init(shouldSucceed: true, mockPosts: mockPosts, mockAccounts: mockAccounts)
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    /// Updated to match `fetchTimeline(useCache:) async throws -> [Post]`
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        // We ignore `useCache` in this mock and always return `mockPosts`.
        guard shouldSucceed else {
            throw MockError.failedToFetchTimeline
        }
        return mockPosts
    }
    
    /// Clears timeline cache (removes all posts) if desired
    func clearTimelineCache() {
        mockPosts.removeAll()
    }
    
    /// Saves the access token
    func saveAccessToken(_ token: String) throws {
        guard shouldSucceed else {
            throw MockError.failedToSaveAccessToken
        }
        self.accessToken = token
    }
    
    /// Clears the stored access token
    func clearAccessToken() throws {
        guard shouldSucceed else {
            throw MockError.failedToClearAccessToken
        }
        self.accessToken = nil
    }
    
    /// Retrieves the stored access token
    func retrieveAccessToken() throws -> String? {
        guard shouldSucceed else {
            throw MockError.failedToRetrieveAccessToken
        }
        return self.accessToken
    }
    
    /// Retrieves the stored instance URL
    func retrieveInstanceURL() throws -> URL? {
        guard shouldSucceed else {
            throw MockError.failedToRetrieveInstanceURL
        }
        return self.baseURL
    }
    
    /// Toggles like/favourite on a post.
    func toggleLike(postID: String) async throws {
        guard shouldSucceed else {
            throw MockError.failedToToggleLike
        }
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isFavourited.toggle()
            mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
        } else {
            throw MockError.postNotFound
        }
    }
    
    /// Toggles repost/reblog on a post.
    func toggleRepost(postID: String) async throws {
        guard shouldSucceed else {
            throw MockError.failedToToggleRepost
        }
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].isReblogged.toggle()
            mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
        } else {
            throw MockError.postNotFound
        }
    }
    
    /// Comments on a post (simulated by incrementing repliesCount)
    func comment(postID: String, content: String) async throws {
        guard shouldSucceed else {
            throw MockError.failedToAddComment
        }
        if let index = mockPosts.firstIndex(where: { $0.id == postID }) {
            mockPosts[index].repliesCount += 1
        } else {
            throw MockError.postNotFound
        }
    }
    
    /// Registers a new account
    func registerAccount(username: String, password: String, instanceURL: URL) async throws -> Account {
        guard shouldSucceed else {
            throw MockError.failedToRegisterAccount
        }
        
        // Check if username already exists
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
        
        // Optionally add a welcome post
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
    
    /// Authenticates a user
    func authenticate(username: String, password: String, instanceURL: URL) async throws -> String {
        guard shouldSucceed else {
            throw MockError.failedToAuthenticate
        }
        
        // Check credentials
        if username.isEmpty || password.isEmpty {
            throw MockError.invalidCredentials
        }
        
        // Assign a mock token
        self.accessToken = "authenticatedMockAccessToken123"
        self.baseURL = instanceURL
        
        return self.accessToken!
    }
    
    // MARK: - Mock Errors
    
    enum MockError: LocalizedError {
        case postNotFound
        case usernameAlreadyExists
        case invalidCredentials
        case failedToFetchTimeline
        case failedToToggleLike
        case failedToToggleRepost
        case failedToAddComment
        case failedToSaveAccessToken
        case failedToClearAccessToken
        case failedToRetrieveAccessToken
        case failedToRetrieveInstanceURL
        case failedToFetchAccounts
        case failedToRegisterAccount
        case failedToAuthenticate
        
        var errorDescription: String? {
            switch self {
            case .postNotFound:
                return "The specified post was not found."
            case .usernameAlreadyExists:
                return "The username is already taken."
            case .invalidCredentials:
                return "Invalid username or password."
            case .failedToFetchTimeline:
                return "Failed to fetch timeline."
            case .failedToToggleLike:
                return "Failed to toggle like."
            case .failedToToggleRepost:
                return "Failed to toggle repost."
            case .failedToAddComment:
                return "Failed to add comment."
            case .failedToSaveAccessToken:
                return "Failed to save access token."
            case .failedToClearAccessToken:
                return "Failed to clear access token."
            case .failedToRetrieveAccessToken:
                return "Failed to retrieve access token."
            case .failedToRetrieveInstanceURL:
                return "Failed to retrieve instance URL."
            case .failedToFetchAccounts:
                return "Failed to fetch accounts."
            case .failedToRegisterAccount:
                return "Failed to register account."
            case .failedToAuthenticate:
                return "Failed to authenticate."
            }
        }
    }
}

