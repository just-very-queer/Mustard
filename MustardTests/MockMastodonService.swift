//
//  MockMastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// A mock service conforming to `MastodonServiceProtocol` for testing and previews.
class MockMastodonService: MastodonServiceProtocol {
    // MARK: - Properties
    
    var baseURL: URL?
    var accessToken: String?
    
    // MARK: - Mock Data
    
    var mockAccounts: [Account] = []
    var mockPosts: [Post] = []
    var shouldSucceed: Bool
    
    // MARK: - Initializer
    
    init(shouldSucceed: Bool = true, mockPosts: [Post]? = nil, mockAccounts: [Account]? = nil) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? []
        
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
        
        self.mockPosts = mockPosts ?? []
        
        if self.mockPosts.isEmpty, !self.mockAccounts.isEmpty {
            self.mockPosts = self.mockAccounts.enumerated().map { index, account in
                Post(
                    id: UUID().uuidString,
                    content: "<p>Mock post #\(index + 1) for preview.</p>",
                    createdAt: Date().addingTimeInterval(Double(-index * 3600)),
                    account: account,
                    mediaAttachments: [],
                    isFavourited: Bool.random(),
                    isReblogged: Bool.random(),
                    reblogsCount: Int.random(in: 0...10),
                    favouritesCount: Int.random(in: 0...20),
                    repliesCount: Int.random(in: 0...5)
                )
            }
        }
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        guard shouldSucceed else { throw MockError.failedToFetchTimeline }
        return mockPosts
    }
    
    func clearTimelineCache() {
        mockPosts.removeAll()
    }
    
    func loadTimelineFromDisk() -> [Post] {
        return mockPosts
    }
    
    func saveTimelineToDisk(_ posts: [Post]) {
        self.mockPosts = posts
    }
    
    func backgroundRefreshTimeline() async {
        // Simulate a refresh by shuffling posts
        mockPosts.shuffle()
    }
    
    func validateToken() async throws {
        guard shouldSucceed, let token = accessToken else { throw MockError.invalidToken }
        // Simulate token validation
        if token.isEmpty {
            throw MockError.invalidToken
        }
    }
    
    func saveAccessToken(_ token: String) throws {
        guard shouldSucceed else { throw MockError.failedToSaveAccessToken }
        self.accessToken = token
    }
    
    func clearAccessToken() throws {
        guard shouldSucceed else { throw MockError.failedToClearAccessToken }
        self.accessToken = nil
    }
    
    func retrieveAccessToken() throws -> String? {
        guard shouldSucceed else { throw MockError.failedToRetrieveAccessToken }
        return accessToken
    }
    
    func retrieveInstanceURL() throws -> URL? {
        guard shouldSucceed else { throw MockError.failedToRetrieveInstanceURL }
        return baseURL
    }
    
    func toggleLike(postID: String) async throws {
        guard shouldSucceed else { throw MockError.failedToToggleLike }
        guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else { throw MockError.postNotFound }
        mockPosts[index].isFavourited.toggle()
        mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
    }
    
    func toggleRepost(postID: String) async throws {
        guard shouldSucceed else { throw MockError.failedToToggleRepost }
        guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else { throw MockError.postNotFound }
        mockPosts[index].isReblogged.toggle()
        mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
    }
    
    func comment(postID: String, content: String) async throws {
        guard shouldSucceed else { throw MockError.failedToAddComment }
        guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else { throw MockError.postNotFound }
        mockPosts[index].repliesCount += 1
    }
    
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        guard shouldSucceed else { throw MockError.failedToRegisterOAuthApp }
        
        // Return a mock OAuthConfig
        let config = OAuthConfig(
            clientID: "mockClientID",
            clientSecret: "mockClientSecret",
            redirectURI: "yourapp://oauth-callback",
            scope: "read write follow"
        )
        return config
    }
    
    func authenticateOAuth(instanceURL: URL, config: OAuthConfig) async throws -> String {
        guard shouldSucceed else { throw MockError.failedToAuthenticateOAuth }
        
        // Return a mock authorization code
        return "mockAuthorizationCode123"
    }
    
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        guard shouldSucceed else { throw MockError.failedToExchangeCode }
        
        // Simulate exchanging code for access token
        self.accessToken = "mockAccessTokenAfterExchange"
    }
    
    // MARK: - Mock Errors
    
    enum MockError: LocalizedError {
        case failedToFetchTimeline
        case failedToSaveAccessToken
        case failedToClearAccessToken
        case failedToRetrieveAccessToken
        case failedToRetrieveInstanceURL
        case failedToToggleLike
        case failedToToggleRepost
        case failedToAddComment
        case failedToRegisterOAuthApp
        case failedToAuthenticateOAuth
        case failedToExchangeCode
        case invalidToken
        case postNotFound
        
        var errorDescription: String? {
            switch self {
            case .failedToFetchTimeline: return "Failed to fetch timeline."
            case .failedToSaveAccessToken: return "Failed to save access token."
            case .failedToClearAccessToken: return "Failed to clear access token."
            case .failedToRetrieveAccessToken: return "Failed to retrieve access token."
            case .failedToRetrieveInstanceURL: return "Failed to retrieve instance URL."
            case .failedToToggleLike: return "Failed to toggle like."
            case .failedToToggleRepost: return "Failed to toggle repost."
            case .failedToAddComment: return "Failed to add comment."
            case .failedToRegisterOAuthApp: return "Failed to register OAuth application."
            case .failedToAuthenticateOAuth: return "Failed to authenticate via OAuth."
            case .failedToExchangeCode: return "Failed to exchange authorization code for access token."
            case .invalidToken: return "Invalid token."
            case .postNotFound: return "Post not found."
            }
        }
    }
}

