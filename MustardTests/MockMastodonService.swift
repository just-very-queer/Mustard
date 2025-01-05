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
    
    var baseURL: URL? = URL(string: "https://example.com")
    var accessToken: String? = "mockAccessToken123"
    
    // MARK: - Mock Data
    
    var mockAccounts: [Account] = []
    var mockPosts: [Post] = []
    var mockTrendingPosts: [Post] = []
    var shouldSucceed: Bool
    
    // MARK: - Initializer
    
    init(
        shouldSucceed: Bool = true,
        mockPosts: [Post]? = nil,
        mockAccounts: [Account]? = nil,
        mockTrendingPosts: [Post]? = nil
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? []
        
        if self.mockAccounts.isEmpty {
            let sampleAccount1 = Account(
                id: "a1",
                username: "user1",
                displayName: "User One",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "user1",
                instanceURL: baseURL!,
                accessToken: "mockAccessToken123"
            )
            
            let sampleAccount2 = Account(
                id: "a2",
                username: "user2",
                displayName: "User Two",
                avatar: URL(string: "https://example.com/avatar2.png")!,
                acct: "user2",
                instanceURL: baseURL!,
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
        
        // Initialize mockTrendingPosts
        self.mockTrendingPosts = mockTrendingPosts ?? generateMockTrendingPosts(count: 3)
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    // MARK: - Timeline Methods
    
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        if shouldSucceed {
            return mockPosts
        } else {
            throw MockError.failedToFetchTimeline
        }
    }
    
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        if shouldSucceed {
            // Simulate pagination by returning a subset of mockPosts
            let pageSize = 20
            let start = (page - 1) * pageSize
            let end = min(start + pageSize, mockPosts.count)
            guard start < end else { return [] }
            return Array(mockPosts[start..<end])
        } else {
            throw MockError.failedToFetchTimelinePage
        }
    }
    
    func clearTimelineCache() async throws {
        if shouldSucceed {
            mockPosts.removeAll()
        } else {
            throw MockError.failedToClearTimelineCache
        }
    }
    
    func loadTimelineFromDisk() async throws -> [Post] {
        if shouldSucceed {
            return mockPosts
        } else {
            throw MockError.failedToLoadTimelineFromDisk
        }
    }
    
    func saveTimelineToDisk(_ posts: [Post]) async throws {
        if shouldSucceed {
            self.mockPosts = posts
        } else {
            throw MockError.failedToSaveTimelineToDisk
        }
    }
    
    func backgroundRefreshTimeline() async {
        if shouldSucceed {
            // Simulate a refresh by adding new mock posts
            mockPosts.append(contentsOf: generateMockPosts(count: 2))
        }
    }
    
    // MARK: - Trending Posts Method
    
    func fetchTrendingPosts() async throws -> [Post] {
        if shouldSucceed {
            return mockTrendingPosts
        } else {
            throw MockError.failedToFetchTrendingPosts
        }
    }
    
    // MARK: - Authentication Methods
    
    func validateToken() async throws {
        if shouldSucceed, let token = accessToken, !token.isEmpty {
            // Simulate successful token validation
        } else {
            throw MockError.invalidToken
        }
    }
    
    func saveAccessToken(_ token: String) async throws {
        if shouldSucceed {
            self.accessToken = token
        } else {
            throw MockError.failedToSaveAccessToken
        }
    }
    
    func clearAccessToken() async throws {
        if shouldSucceed {
            self.accessToken = nil
        } else {
            throw MockError.failedToClearAccessToken
        }
    }
    
    func retrieveAccessToken() async throws -> String? {
        if shouldSucceed {
            return accessToken
        } else {
            throw MockError.failedToRetrieveAccessToken
        }
    }
    
    func retrieveInstanceURL() async throws -> URL? {
        if shouldSucceed {
            return baseURL
        } else {
            throw MockError.failedToRetrieveInstanceURL
        }
    }
    
    // MARK: - Post Actions
    
    func toggleLike(postID: String) async throws {
        if shouldSucceed {
            guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
                throw MockError.postNotFound
            }
            mockPosts[index].isFavourited.toggle()
            mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
        } else {
            throw MockError.failedToToggleLike
        }
    }
    
    func toggleRepost(postID: String) async throws {
        if shouldSucceed {
            guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
                throw MockError.postNotFound
            }
            mockPosts[index].isReblogged.toggle()
            mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
        } else {
            throw MockError.failedToToggleRepost
        }
    }
    
    func comment(postID: String, content: String) async throws {
        if shouldSucceed {
            guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
                throw MockError.postNotFound
            }
            mockPosts[index].repliesCount += 1
            // Optionally, add the comment to a comments array if your model supports it
        } else {
            throw MockError.failedToAddComment
        }
    }
    
    // MARK: - OAuth Methods
    
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        if shouldSucceed {
            // Return a mock OAuthConfig
            let config = OAuthConfig(
                clientID: "mockClientID",
                clientSecret: "mockClientSecret",
                redirectURI: "yourapp://oauth-callback",
                scope: "read write follow"
            )
            return config
        } else {
            throw MockError.failedToRegisterOAuthApp
        }
    }
    
    func authenticateOAuth(instanceURL: URL, config: OAuthConfig) async throws -> String {
        if shouldSucceed {
            // Return a mock authorization code
            return "mockAuthorizationCode123"
        } else {
            throw MockError.failedToAuthenticateOAuth
        }
    }
    
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        if shouldSucceed {
            // Simulate exchanging code for access token
            self.accessToken = "mockAccessTokenAfterExchange"
        } else {
            throw MockError.failedToExchangeCode
        }
    }
    
    // MARK: - Streaming Methods
    
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        if shouldSucceed {
            return AsyncThrowingStream { continuation in
                // Simulate streaming by periodically sending mock posts
                for post in mockPosts {
                    continuation.yield(post)
                }
                continuation.finish()
            }
        } else {
            throw MockError.failedToStreamTimeline
        }
    }
    
    // MARK: - Private Mock Data Methods
    
    private func generateMockPosts(count: Int) -> [Post] {
        guard !mockAccounts.isEmpty else { return [] }
        let accountsToUse = mockAccounts
        return (1...count).map { index in
            let randomAccount = accountsToUse[index % accountsToUse.count]
            return Post(
                id: "mockPost\(mockPosts.count + index)",
                content: "<p>Mock post content #\(mockPosts.count + index) with <strong>HTML</strong> support.</p>",
                createdAt: Date().addingTimeInterval(Double(-index * 3600)),
                account: randomAccount,
                mediaAttachments: [],
                isFavourited: Bool.random(),
                isReblogged: Bool.random(),
                reblogsCount: Int.random(in: 0...20),
                favouritesCount: Int.random(in: 0...50),
                repliesCount: Int.random(in: 0...10)
            )
        }
    }
    
    private func generateMockTrendingPosts(count: Int) -> [Post] {
        guard !mockAccounts.isEmpty else { return [] }
        let accountsToUse = mockAccounts
        return (1...count).map { index in
            let randomAccount = accountsToUse[index % accountsToUse.count]
            return Post(
                id: "mockTrendingPost\(index)",
                content: "<p>Trending post content #\(index) with <em>HTML</em> support.</p>",
                createdAt: Date().addingTimeInterval(Double(-index * 7200)),
                account: randomAccount,
                mediaAttachments: [],
                isFavourited: Bool.random(),
                isReblogged: Bool.random(),
                reblogsCount: Int.random(in: 0...30),
                favouritesCount: Int.random(in: 0...60),
                repliesCount: Int.random(in: 0...15)
            )
        }
    }
    
    // MARK: - Mock Errors
    
    enum MockError: LocalizedError {
        case failedToFetchTimeline
        case failedToFetchTimelinePage
        case failedToClearTimelineCache
        case failedToLoadTimelineFromDisk
        case failedToSaveTimelineToDisk
        case failedToFetchTrendingPosts
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
        case failedToStreamTimeline
        case invalidToken
        case postNotFound

        var errorDescription: String? {
            switch self {
            case .failedToFetchTimeline: return "Failed to fetch timeline."
            case .failedToFetchTimelinePage: return "Failed to fetch timeline page."
            case .failedToClearTimelineCache: return "Failed to clear timeline cache."
            case .failedToLoadTimelineFromDisk: return "Failed to load timeline from disk."
            case .failedToSaveTimelineToDisk: return "Failed to save timeline to disk."
            case .failedToFetchTrendingPosts: return "Failed to fetch trending posts."
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
            case .failedToStreamTimeline: return "Failed to stream timeline."
            case .invalidToken: return "Invalid token."
            case .postNotFound: return "Post not found."
            }
        }
    }
}
