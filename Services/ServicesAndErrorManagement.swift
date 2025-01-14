//
//  ServicesAndErrorManagement.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import Foundation
import SwiftUI
import OSLog
import CoreLocation

// MARK: - AppError

struct AppError: Identifiable, Error {
    let id = UUID()
    let type: ErrorType
    let underlyingError: Error?
    let timestamp: Date = Date()

    enum ErrorType {
        case generic(String)
        case mastodon(MastodonError)
        case authentication(AuthenticationError)
    }

    enum MastodonError: Equatable {
        case missingCredentials
        case invalidResponse
        case badRequest
        case unauthorized
        case forbidden
        case notFound
        case serverError(status: Int)
        case encodingError
        case decodingError
        case networkError(message: String)
        case oauthError(message: String)
        case unknown(status: Int)
        case failedToFetchTimeline
        case failedToFetchTimelinePage
        case failedToClearTimelineCache
        case failedToLoadTimelineFromDisk
        case failedToSaveTimelineToDisk
        case failedToFetchTrendingPosts
        case invalidToken
        case failedToSaveAccessToken
        case failedToClearAccessToken
        case failedToRetrieveAccessToken
        case failedToRetrieveInstanceURL
        case postNotFound
        case failedToRegisterOAuthApp
        case failedToExchangeCode
        case failedToStreamTimeline
        case invalidAuthorizationCode

        static func == (lhs: MastodonError, rhs: MastodonError) -> Bool {
            switch (lhs, rhs) {
            case (.missingCredentials, .missingCredentials),
                 (.invalidResponse, .invalidResponse),
                 (.badRequest, .badRequest),
                 (.unauthorized, .unauthorized),
                 (.forbidden, .forbidden),
                 (.notFound, .notFound),
                 (.failedToFetchTimeline, .failedToFetchTimeline),
                 (.failedToFetchTimelinePage, .failedToFetchTimelinePage),
                 (.failedToClearTimelineCache, .failedToClearTimelineCache),
                 (.failedToLoadTimelineFromDisk, .failedToLoadTimelineFromDisk),
                 (.failedToSaveTimelineToDisk, .failedToSaveTimelineToDisk),
                 (.failedToFetchTrendingPosts, .failedToFetchTrendingPosts),
                 (.invalidToken, .invalidToken),
                 (.failedToSaveAccessToken, .failedToSaveAccessToken),
                 (.failedToClearAccessToken, .failedToClearAccessToken),
                 (.failedToRetrieveAccessToken, .failedToRetrieveAccessToken),
                 (.failedToRetrieveInstanceURL, .failedToRetrieveInstanceURL),
                 (.postNotFound, .postNotFound),
                 (.failedToRegisterOAuthApp, .failedToRegisterOAuthApp),
                 (.failedToExchangeCode, .failedToExchangeCode),
                 (.failedToStreamTimeline, .failedToStreamTimeline),
                 (.invalidAuthorizationCode, .invalidAuthorizationCode):
                return true
            case (.serverError(let lhsStatus), .serverError(let rhsStatus)):
                return lhsStatus == rhsStatus
            case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
                return lhsMessage == rhsMessage
            case (.oauthError(let lhsMessage), .oauthError(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }

    enum AuthenticationError: Equatable {
        case invalidAuthorizationCode
        case webAuthSessionFailed
        case noAuthorizationCode
        case unknown
    }

    // MARK: - Initializers
    init(message: String, underlyingError: Error? = nil) {
        self.type = .generic(message)
        self.underlyingError = underlyingError
    }

    init(mastodon: MastodonError, underlyingError: Error? = nil) {
        self.type = .mastodon(mastodon)
        self.underlyingError = underlyingError
    }

    init(authentication: AuthenticationError, underlyingError: Error? = nil) {
        self.type = .authentication(authentication)
        self.underlyingError = underlyingError
    }

    // MARK: - Computed Properties

    var message: String {
        switch type {
        case .generic(let msg):
            return msg
        case .mastodon(let error):
            return describeMastodonError(error)
        case .authentication(let authError):
            return describeAuthenticationError(authError)
        }
    }

    private func describeMastodonError(_ error: MastodonError) -> String {
        switch error {
        case .missingCredentials:
            return "Missing base URL or access token."
        case .invalidResponse:
            return "Invalid response from server."
        case .badRequest:
            return "Bad request."
        case .unauthorized:
            return "Unauthorized access."
        case .forbidden:
            return "Forbidden action."
        case .notFound:
            return "Resource not found."
        case .serverError(let status):
            return "Server error with status code \(status)."
        case .encodingError:
            return "Failed to encode data."
        case .decodingError:
            return "Failed to decode data."
        case .networkError(let message):
            return "Network error: \(message)"
        case .oauthError(let message):
            return "OAuth error: \(message)"
        case .unknown(let status):
            return "Unknown error with status code \(status)."
        case .failedToFetchTimeline:
            return "Unable to fetch timeline."
        case .failedToFetchTimelinePage:
            return "Unable to fetch more timeline posts."
        case .failedToClearTimelineCache:
            return "Failed to clear timeline cache."
        case .failedToLoadTimelineFromDisk:
            return "Failed to load timeline from disk."
        case .failedToSaveTimelineToDisk:
            return "Failed to save timeline to disk."
        case .failedToFetchTrendingPosts:
            return "Failed to fetch trending posts."
        case .invalidToken:
            return "Invalid access token."
        case .failedToSaveAccessToken:
            return "Failed to save access token."
        case .failedToClearAccessToken:
            return "Failed to clear access token."
        case .failedToRetrieveAccessToken:
            return "Failed to retrieve access token."
        case .failedToRetrieveInstanceURL:
            return "Failed to retrieve instance URL."
        case .postNotFound:
            return "Post not found."
        case .failedToRegisterOAuthApp:
            return "Failed to register OAuth application."
        case .failedToExchangeCode:
            return "Failed to exchange authorization code."
        case .failedToStreamTimeline:
            return "Failed to stream timeline."
        case .invalidAuthorizationCode:
            return "Invalid authorization code provided."
        }
    }

    private func describeAuthenticationError(_ error: AuthenticationError) -> String {
        switch error {
            
        case .invalidAuthorizationCode:
            return "Invalid authorization code provided."
        case .webAuthSessionFailed:
            return "Web authentication session failed to start."
        case .noAuthorizationCode:
            return "Authorization code was not received."
        case .unknown:
            return "An unknown authentication error occurred."
        }
    }

    var isRecoverable: Bool {
        switch type {
        case .generic:
            return true
        case .mastodon(let error):
            switch error {
            case .missingCredentials:
                return true
            case .networkError:
                return true
            default:
                return false
            }
        case .authentication:
            return true
        }
    }

    var recoverySuggestion: String? {
        switch type {
        case .generic:
            return "Please try again."
        case .mastodon(let error):
            switch error {
            case .missingCredentials:
                return "Please verify your login credentials."
            case .networkError:
                return "Please check your internet connection and try again."
            default:
                return nil
            }
        case .authentication(let authError):
            switch authError {
            case .invalidAuthorizationCode:
                return "Please check your authorization code and try again."
            case .webAuthSessionFailed:
                return "Ensure that web authentication is available and try again."
            case .noAuthorizationCode:
                return "Authorization code was not received. Please try logging in again."
            case .unknown:
                return "An unexpected error occurred during authentication."
            }
        }
    }
    
}

// MARK: - LocationManager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            print("Location access denied or restricted.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to update location: \(error.localizedDescription)")
    }
}

// MARK: - MockService

@MainActor
class MockService: MastodonServiceProtocol {
    // MARK: - Properties
    private let pageSize = 20
    var baseURL: URL? = URL(string: "https://example.com")
    var accessToken: String? = "mockAccessToken123"
    var shouldSucceed: Bool
    private(set) var mockAccounts: [Account]
    private(set) var mockPosts: [Post]
    private(set) var mockTrendingPosts: [Post]

    // MARK: - Initialization
    init(
        shouldSucceed: Bool = true,
        mockAccounts: [Account]? = nil,
        mockPosts: [Post]? = nil,
        mockTrendingPosts: [Post]? = nil
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockAccounts = mockAccounts ?? MockService.generateMockAccounts()
        self.mockPosts = mockPosts ?? MockService.generateMockPosts(from: self.mockAccounts, count: 20)
        self.mockTrendingPosts = mockTrendingPosts ?? MockService.generateMockPosts(from: self.mockAccounts, count: 5)
    }

    // MARK: - MastodonServiceProtocol Methods

    // MARK: Initialization
    func ensureInitialized() async {
        // No-op in the mock implementation
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

    func clearTimelineCache() async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to clear timeline cache.") }
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
        mockPosts.append(contentsOf: MockService.generateMockPosts(from: mockAccounts, count: 5))
    }

    func fetchTrendingPosts() async throws -> [Post] {
        try validateData(mockTrendingPosts, errorMessage: "Failed to fetch trending posts.")
    }

    // MARK: User Methods
    func fetchCurrentUser() async throws -> User {
        guard shouldSucceed, let account = mockAccounts.first else {
            throw AppError(message: "Failed to fetch current user.")
        }
        return User(
            id: account.id,
            username: account.username,
            displayName: account.displayName,
            avatar: account.avatar,
            url: account.url
        )
    }

    // MARK: Authentication Methods
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
                displayName: "User One",
                avatar: baseURL.appendingPathComponent("avatar1.png"),
                acct: "@user1",
                url: baseURL
            ),
            Account(
                id: "a2",
                username: "user2",
                displayName: "User Two",
                avatar: baseURL.appendingPathComponent("avatar2.png"),
                acct: "@user2",
                url: baseURL
            )
        ]
    }

    private static func generateMockPosts(from accounts: [Account], count: Int) -> [Post] {
        (1...count).compactMap { i in
            guard let account = accounts.randomElement() else { return nil }
            return Post(
                id: "post\(i)",
                content: "<p>Mock post #\(i)</p>",
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
}
