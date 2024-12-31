//
//  PreviewService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// A mock implementation of `MastodonServiceProtocol` for previews and testing.
class PreviewService: MastodonServiceProtocol {
    // MARK: - Properties

    var baseURL: URL? = URL(string: "https://example.com")
    var accessToken: String? = "mockAccessToken123"

    /// Mock data for posts and accounts
    var mockPosts: [Post] = []
    var mockAccounts: [Account] = []
    var shouldSucceed: Bool

    // MARK: - Initialization

    init(shouldSucceed: Bool = true, mockPosts: [Post]? = nil, mockAccounts: [Account]? = nil) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? []
        
        if self.mockAccounts.isEmpty {
            let sampleAccount1 = Account(
                id: "mockAccount1",
                username: "testuser1",
                displayName: "Test User 1",
                avatar: URL(string: "https://example.com/avatar1.png")!,
                acct: "testuser1",
                instanceURL: baseURL!,
                accessToken: "mockAccessToken123"
            )
            
            let sampleAccount2 = Account(
                id: "mockAccount2",
                username: "testuser2",
                displayName: "Test User 2",
                avatar: URL(string: "https://example.com/avatar2.png")!,
                acct: "testuser2",
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
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        if shouldSucceed {
            return mockPosts
        } else {
            throw MockError.failedToFetchTimeline
        }
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
        if shouldSucceed {
            // Simulate adding new posts
            mockPosts.append(contentsOf: generateMockPosts(count: 2))
        }
    }
    
    func validateToken() async throws {
        if shouldSucceed, let token = accessToken, !token.isEmpty {
            // Simulate successful token validation
        } else {
            throw MockError.invalidToken
        }
    }
    
    func saveAccessToken(_ token: String) throws {
        if shouldSucceed {
            self.accessToken = token
        } else {
            throw MockError.failedToSaveAccessToken
        }
    }
    
    func clearAccessToken() throws {
        if shouldSucceed {
            self.accessToken = nil
        } else {
            throw MockError.failedToClearAccessToken
        }
    }
    
    func retrieveAccessToken() throws -> String? {
        if shouldSucceed {
            return accessToken
        } else {
            throw MockError.failedToRetrieveAccessToken
        }
    }
    
    func retrieveInstanceURL() throws -> URL? {
        if shouldSucceed {
            return baseURL
        } else {
            throw MockError.failedToRetrieveInstanceURL
        }
    }
    
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
        } else {
            throw MockError.failedToAddComment
        }
    }
    
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

