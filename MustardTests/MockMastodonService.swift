//
//  MockMastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import Combine

@MainActor
class MockMastodonService: MastodonServiceProtocol {
    func clearAllKeychainData() async throws {
        
    }
    
    
    // MARK: - Properties
    private let pageSize = 20
    var baseURL: URL?
    var accessToken: String?
    var shouldSucceed: Bool
    private(set) var mockAccounts: [Account]
    private(set) var mockPosts: [Post]
    private(set) var mockTrendingPosts: [Post]
    var tokenCreationDate: Date?

    
    // MARK: - Initialization
    init(
        shouldSucceed: Bool = true,
        mockAccounts: [Mustard.Account]? = nil,
        mockPosts: [Post]? = nil,
        mockTrendingPosts: [Post]? = nil
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? MockMastodonService.generateMockAccounts()
        self.mockPosts = mockPosts ?? MockMastodonService.generateMockPosts(from: self.mockAccounts, count: 20)
        self.mockTrendingPosts = mockTrendingPosts ?? MockMastodonService.generateMockPosts(from: self.mockAccounts, count: 5)
    }
    
    // MARK: - MastodonServiceProtocol Methods
    
    // MARK: Initialization
    func ensureInitialized() async throws {
        // No-op in the mock implementation
    }
    
    // MARK: Authentication
    func isAuthenticated() async throws -> Bool {
        return shouldSucceed && baseURL != nil && accessToken != nil
    }
    
    // MARK: Timeline Methods
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        try validateData(mockPosts, errorMessage: "Failed to fetch timeline.")
    }
    
    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        let start = (page - 1) * pageSize
        guard start < mockPosts.count else { return [] }
        let end = min(start + pageSize, mockPosts.count)
        return try validateData(Array(mockPosts[start..<end]), errorMessage: "Failed to fetch timeline page.")
    }
    
    func clearTimelineCache() {
        mockPosts.removeAll()
    }
    
    func loadTimelineFromDisk() async throws -> [Post] {
        try validateData(mockPosts, errorMessage: "Failed to load timeline from disk.")
    }
    
    func saveTimelineToDisk(_ posts: [Post]) async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to save timeline to disk.") }
        mockPosts = posts
    }
    
    func backgroundRefreshTimeline() async {
        guard shouldSucceed else { return }
        mockPosts.append(contentsOf: MockMastodonService.generateMockPosts(from: mockAccounts, count: 5))
    }
    
    func fetchTrendingPosts() async throws -> [Post] {
        try validateData(mockTrendingPosts, errorMessage: "Failed to fetch trending posts.")
    }
    
    // MARK: User Methods
    private static func generateMockUser(from account: Account) -> User {
        // Mock values
        let mockAvatarURL = URL(string: "https://example.com/avatar.jpg")!
        let mockHeaderURL = URL(string: "https://example.com/header.jpg")!
        let dateFormatter = ISO8601DateFormatter()
        let createdAtDate = dateFormatter.date(from: "2023-01-01T00:00:00.000Z") ?? Date()

        // Create the mock User from Account
        return User(
            id: account.id,
            username: account.username,
            acct: account.acct,
            display_name: account.display_name,  // Ensure that `display_name` is correctly referenced
            locked: false,
            bot: false,
            discoverable: true, // Optional, providing true for mock data
            indexable: true,    // Optional, providing true for mock data
            group: false,
            created_at: createdAtDate,
            note: "<p>This is a mock user account for testing.</p>",
            url: account.url,
            avatar: mockAvatarURL,
            avatar_static: mockAvatarURL,
            header: mockHeaderURL,
            header_static: mockHeaderURL,
            followers_count: 100,
            following_count: 50,
            statuses_count: 200,
            last_status_at: "2024-01-13", // Optional String, mock value
            hide_collections: false, // Optional, providing false
            noindex: false, // Optional, providing false
            source: User.Source(
                privacy: "public",
                sensitive: false,
                language: "en",
                note: "This is a mock user profile.",
                fields: [], // Mock empty fields
                follow_requests_count: 0,
                hide_collections: false,
                discoverable: true,
                indexable: true
            ),
            emojis: [], // Mock empty emojis
            roles: [], // Mock empty roles
            fields: []  // Mock empty fields
        )
    }
    
    func fetchCurrentUser() async throws -> User {
        guard shouldSucceed, let accountData = mockAccounts.first else {
            throw AppError(message: "Failed to fetch current user.")
        }
        return MockMastodonService.generateMockUser(from: accountData)
    }
    
// MARK:- Authentication Methods
    func validateToken() async throws {
        guard shouldSucceed, accessToken != nil else { throw AppError(message: "Invalid token.") }
    }
    
    func saveAccessToken(_ token: String) async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to save access token.") }
        accessToken = token
    }
    
    func clearAccessToken() async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to clear access token.") }
        accessToken = nil
    }
    
    func retrieveAccessToken() async throws -> String? {
        try validateData(accessToken, errorMessage: "Failed to retrieve access token.")
    }
    
    func retrieveInstanceURL() async throws -> URL? {
        try validateData(baseURL, errorMessage: "Failed to retrieve instance URL.")
    }
    
    // MARK: Post Actions
    func toggleLike(postID: String) async throws {
        try modifyPost(postID: postID, action: "like") { post in
            post.isFavourited.toggle()
            post.favouritesCount += post.isFavourited ? 1 : -1
        }
    }
    
    func toggleRepost(postID: String) async throws {
        try modifyPost(postID: postID, action: "repost") { post in
            post.isReblogged.toggle()
            post.reblogsCount += post.isReblogged ? 1 : -1
        }
    }
    
    func comment(postID: String, content: String) async throws {
        try modifyPost(postID: postID, action: "comment") { post in
            post.repliesCount += 1
        }
    }
    
    // MARK: OAuth Methods
    func registerOAuthApp(instanceURL: URL) async throws -> OAuthConfig {
        guard shouldSucceed else { throw AppError(message: "Failed to register OAuth application.") }
        return OAuthConfig(
            clientID: "mockClientID",
            clientSecret: "mockClientSecret",
            redirectURI: "yourapp://oauth-callback",
            scope: "read write follow"
        )
    }

    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to exchange authorization code.") }
        accessToken = "mockAccessTokenAfterExchange"
    }
    
    func isTokenNearExpiry() -> Bool {
        guard let creationDate = tokenCreationDate else { return true }
        let expiryThreshold = TimeInterval(3600 * 24 * 80)
        return Date().timeIntervalSince(creationDate) > expiryThreshold
    }

    func reauthenticate(config: OAuthConfig, instanceURL: URL) async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to reauthenticate.") }
        accessToken = "mockNewAccessToken"
        tokenCreationDate = Date()
    }
    
    func streamTimeline() async throws -> AsyncThrowingStream<Post, Error> {
        guard shouldSucceed else { throw AppError(message: "Failed to stream timeline.") }
        return AsyncThrowingStream { continuation in
            for post in mockPosts {
                continuation.yield(post)
            }
            continuation.finish()
        }
    }
    
    // MARK: - Helpers
    
    private func validateData<T>(_ data: T?, errorMessage: String) throws -> T {
        guard shouldSucceed, let data = data else { throw AppError(message: errorMessage) }
        return data
    }
    
    private func modifyPost(postID: String, action: String, update: (inout Post) -> Void) throws {
        guard let index = mockPosts.firstIndex(where: { $0.id == postID }) else {
            throw AppError(mastodon: .postNotFound)
        }
        var post = mockPosts[index]
        update(&post)
        mockPosts[index] = post
    }
    
    // MARK: - Static Mock Data Generators
    
private static func generateMockAccounts() -> [Account] {
            let baseURL = URL(string: "https://example.com")!
            return [
                Account(
                    id: "a1",
                    username: "user1",
                    displayName: "User One", // Corrected label to match Account model
                    avatar: baseURL.appendingPathComponent("avatar1.png"),
                    acct: "user1",
                    url: baseURL,
                    accessToken: "token1"
                ),
                Account(
                    id: "a2",
                    username: "user2",
                    displayName: "User Two", // Corrected label
                    avatar: baseURL.appendingPathComponent("avatar2.png"),
                    acct: "user2",
                    url: baseURL,
                    accessToken: "token2"
                )
                // Add more mock accounts as needed
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

        var errorDescription: String? {
            switch self {
            case .failedToFetchTimeline:
                return "Failed to fetch timeline."
            case .failedToFetchTimelinePage:
                return "Failed to fetch timeline page."
            case .failedToClearTimelineCache:
                return "Failed to clear timeline cache."
            case .failedToLoadTimelineFromDisk:
                return "Failed to load timeline from disk."
            case .failedToSaveTimelineToDisk:
                return "Failed to save timeline to disk."
            case .failedToFetchTrendingPosts:
                return "Failed to fetch trending posts."
            case .failedToSaveAccessToken:
                return "Failed to save access token."
            case .failedToClearAccessToken:
                return "Failed to clear access token."
            case .failedToRetrieveAccessToken:
                return "Failed to retrieve access token."
            case .failedToRetrieveInstanceURL:
                return "Failed to retrieve instance URL."
            case .failedToToggleLike:
                return "Failed to toggle like status."
            case .failedToToggleRepost:
                return "Failed to toggle repost status."
            case .failedToExchangeCode:
                return "Failed to exchange authorization code."
            case .failedToRegisterOAuthApp:
                return "Failed to register OAuth application."
            case .failedToStreamTimeline:
                return "Failed to stream timeline."
            case .invalidToken:
                return "Invalid or missing access token."
            case .postNotFound:
                return "Post not found."
            case .failedToInitialize:
                return "Service initialization failed."
            case .failedToFetchCurrentUser:
                return "Failed to fetch current user."
            }
        }
        
    }
    
    func authenticate() async {
        self.baseURL = URL(string: "https://mastodon.social")!
        self.accessToken = "mockAccessToken"
    }
}
