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
        case networkError(underlying: Error)
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

        static func == (lhs: MastodonError, rhs: MastodonError) -> Bool {
            switch (lhs, rhs) {
            case (.missingCredentials, .missingCredentials),
                 (.failedToFetchTimeline, .failedToFetchTimeline),
                 (.failedToRetrieveAccessToken, .failedToRetrieveAccessToken):
                return true
            case (.serverError(let lhsStatus), .serverError(let rhsStatus)):
                return lhsStatus == rhsStatus
            case (.networkError(let lhsUnderlying), .networkError(let rhsUnderlying)):
                return lhsUnderlying.localizedDescription == rhsUnderlying.localizedDescription
            default:
                return false
            }
        }
    }

    init(message: String, underlyingError: Error? = nil) {
        self.type = .generic(message)
        self.underlyingError = underlyingError
    }

    init(mastodon: MastodonError, underlying: Error? = nil) {
        self.type = .mastodon(mastodon)
        self.underlyingError = underlying
    }

    var message: String {
        switch type {
        case .generic(let msg): return msg
        case .mastodon(let error): return describeMastodonError(error)
        }
    }

    private func describeMastodonError(_ error: MastodonError) -> String {
        switch error {
        case .missingCredentials: return "Missing base URL or access token."
        case .serverError(let code): return "Server error with status code \(code)."
        case .failedToFetchTimeline: return "Unable to fetch timeline."
        default: return "An unexpected error occurred."
        }
    }

    var isRecoverable: Bool {
        switch type {
        case .generic: return true
        case .mastodon(let error):
            return error == .missingCredentials || error == .networkError(underlying: NSError(domain: "", code: -1009))
        }
    }

    var recoverySuggestion: String? {
        switch type {
        case .generic: return "Please try again."
        case .mastodon(let error):
            switch error {
            case .missingCredentials: return "Please verify your login credentials."
            default: return nil
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
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: print("Location access denied or restricted.")
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
        return try validateData(mockPosts, errorMessage: "Failed to fetch timeline.")
    }

    func fetchTimeline(page: Int, useCache: Bool) async throws -> [Post] {
        let start = (page - 1) * pageSize
        guard start < mockPosts.count else { return [] }
        return try validateData(Array(mockPosts[start..<min(start + pageSize, mockPosts.count)]), errorMessage: "Failed to fetch timeline page.")
    }

    func clearTimelineCache() async throws {
        guard shouldSucceed else { throw AppError(message: "Failed to clear timeline cache.") }
        mockPosts.removeAll()
    }

    func loadTimelineFromDisk() async throws -> [Post] {
        return try validateData(mockPosts, errorMessage: "Failed to load timeline from disk.")
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
        return try validateData(mockTrendingPosts, errorMessage: "Failed to fetch trending posts.")
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
            instanceURL: account.instanceURL
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
        return try validateData(accessToken, errorMessage: "Failed to retrieve access token.")
    }

    func retrieveInstanceURL() async throws -> URL? {
        return try validateData(baseURL, errorMessage: "Failed to retrieve instance URL.")
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
        return OAuthConfig(clientID: "mockClientID", clientSecret: "mockClientSecret", redirectURI: "yourapp://oauth-callback", scope: "read write follow")
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
            throw AppError(message: "Failed to \(action). Post not found.")
        }
        update(&mockPosts[index])
    }

    // MARK: - Static Mock Data Generators
    static func generateMockAccounts() -> [Account] {
        let baseURL = URL(string: "https://example.com")!
        return [
            Account(id: "a1", username: "user1", displayName: "User One", avatar: baseURL.appendingPathComponent("avatar1.png"), acct: "user1", instanceURL: baseURL),
            Account(id: "a2", username: "user2", displayName: "User Two", avatar: baseURL.appendingPathComponent("avatar2.png"), acct: "user2", instanceURL: baseURL)
        ]
    }

    static func generateMockPosts(from accounts: [Account], count: Int) -> [Post] {
        return (1...count).compactMap { i in
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

