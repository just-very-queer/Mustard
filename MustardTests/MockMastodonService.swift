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

    // Mock data
    var mockAccounts: [Account]
    var mockPosts: [Post]
    var mockTrendingPosts: [Post]
    var shouldSucceed: Bool

    // MARK: - Initializer
    init(
        shouldSucceed: Bool = true,
        mockPosts: [Post]? = nil,
        mockAccounts: [Account]? = nil,
        mockTrendingPosts: [Post]? = nil
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? MockMastodonService.generateMockAccounts()
        self.mockPosts = mockPosts ?? MockMastodonService.generateMockPosts(from: self.mockAccounts, count: 20)
        self.mockTrendingPosts = mockTrendingPosts ?? MockMastodonService.generateMockPosts(from: self.mockAccounts, count: 5)
    }

    // MARK: - MastodonServiceProtocol Methods
    func ensureInitialized() async throws {
        guard shouldSucceed else {
            throw MockError.failedToInitialize
        }
    }

    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        guard shouldSucceed else { throw MockError.failedToFetchTimeline }
        return mockPosts
    }

    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        guard shouldSucceed else { throw MockError.failedToFetchTimelinePage }
        let pageSize = 10
        let startIndex = (page - 1) * pageSize
        guard startIndex < mockPosts.count else { return [] }
        return Array(mockPosts[startIndex..<min(startIndex + pageSize, mockPosts.count)])
    }

    func clearTimelineCache() async throws {
        guard shouldSucceed else { throw MockError.failedToClearTimelineCache }
        mockPosts.removeAll()
    }

    func loadTimelineFromDisk() async throws -> [Post] {
        guard shouldSucceed else { throw MockError.failedToLoadTimelineFromDisk }
        return mockPosts
    }

    func saveTimelineToDisk(_ posts: [Post]) async throws {
        guard shouldSucceed else { throw MockError.failedToSaveTimelineToDisk }
        mockPosts = posts
    }

    func backgroundRefreshTimeline() async {
        if shouldSucceed {
            let newPosts = MockMastodonService.generateMockPosts(from: mockAccounts, count: 5)
            mockPosts.append(contentsOf: newPosts)
        }
    }

    func fetchTrendingPosts() async throws -> [Post] {
        guard shouldSucceed else { throw MockError.failedToFetchTrendingPosts }
        return mockTrendingPosts
    }

    func validateToken() async throws {
        guard shouldSucceed, let token = accessToken, !token.isEmpty else { throw MockError.invalidToken }
    }

    func saveAccessToken(_ token: String) async throws {
        guard shouldSucceed else { throw MockError.failedToSaveAccessToken }
        accessToken = token
    }

    func clearAccessToken() async throws {
        guard shouldSucceed else { throw MockError.failedToClearAccessToken }
        accessToken = nil
    }

    func retrieveAccessToken() async throws -> String? {
        guard shouldSucceed else { throw MockError.failedToRetrieveAccessToken }
        return accessToken
    }

    func retrieveInstanceURL() async throws -> URL? {
        guard shouldSucceed else { throw MockError.failedToRetrieveInstanceURL }
        return baseURL
    }

    func toggleLike(postID: String) async throws {
        guard shouldSucceed, let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
            throw MockError.postNotFound
        }
        mockPosts[index].isFavourited.toggle()
        mockPosts[index].favouritesCount += mockPosts[index].isFavourited ? 1 : -1
    }

    func toggleRepost(postID: String) async throws {
        guard shouldSucceed, let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
            throw MockError.postNotFound
        }
        mockPosts[index].isReblogged.toggle()
        mockPosts[index].reblogsCount += mockPosts[index].isReblogged ? 1 : -1
    }

    func comment(postID: String, content: String) async throws {
        guard shouldSucceed, let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
            throw MockError.postNotFound
        }
        mockPosts[index].repliesCount += 1
    }

    func fetchCurrentUser() async throws -> User {
        guard shouldSucceed, let mockAccount = mockAccounts.first else {
            throw MockError.failedToFetchCurrentUser
        }
        return User(
            id: mockAccount.id,
            username: mockAccount.username,
            displayName: mockAccount.displayName,
            avatar: mockAccount.avatar, // Correctly passing URL?
            instanceURL: mockAccount.instanceURL // Correctly passing URL
        )
    }

    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        guard shouldSucceed else { throw MockError.failedToRegisterOAuthApp }
        return OAuthConfig(
            clientID: "mockClientID",
            clientSecret: "mockClientSecret",
            redirectURI: "yourapp://oauth-callback",
            scope: "read write follow"
        )
    }

    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        guard shouldSucceed else { throw MockError.failedToExchangeCode }
        accessToken = "mockAccessTokenAfterExchange"
    }

    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard shouldSucceed else { throw MockError.failedToStreamTimeline }
        return AsyncThrowingStream { continuation in
            for post in mockPosts {
                continuation.yield(post)
            }
            continuation.finish()
        }
    }

    // MARK: - Mock Data Generation
    private static func generateMockAccounts() -> [Account] {
        let baseURL = URL(string: "https://example.com")!
        return [
            Account(
                id: "a1",
                username: "user1",
                displayName: "User One",
                avatar: baseURL.appendingPathComponent("avatar1.png"),
                acct: "user1",
                instanceURL: baseURL
            ),
            Account(
                id: "a2",
                username: "user2",
                displayName: "User Two",
                avatar: baseURL.appendingPathComponent("avatar2.png"),
                acct: "user2",
                instanceURL: baseURL
            )
        ]
    }

    private static func generateMockPosts(from accounts: [Account], count: Int) -> [Post] {
        return (1...count).compactMap { i in
            guard let account = accounts.randomElement() else { return nil }
            return Post(
                id: "post\(i)",
                content: "<p>Mock post content #\(i)</p>",
                createdAt: Date().addingTimeInterval(-Double(i * 3600)),
                account: account,
                mediaAttachments: [],
                isFavourited: Bool.random(),
                isReblogged: Bool.random(),
                reblogsCount: Int.random(in: 0...20),
                favouritesCount: Int.random(in: 0...50),
                repliesCount: Int.random(in: 0...10)
            )
        }
    }

    // MARK: - Mock Error
    enum MockError: Error, LocalizedError {
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
        case failedToExchangeCode
        case failedToRegisterOAuthApp
        case failedToStreamTimeline
        case invalidToken
        case postNotFound
        case failedToInitialize
        case failedToFetchCurrentUser
    }
}
