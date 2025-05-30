//
//  TimelineService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Updated to use MastodonAPIService
//

import Foundation
import OSLog
import CoreLocation
import Combine

@MainActor
class TimelineService: TimelineServiceProtocol { // Added conformance
    // MARK: - Dependencies
    private let mastodonAPIService: MastodonAPIService
    private let cacheService: CacheService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private let trendingService: TrendingService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineService")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published private(set) var currentTimelinePosts: [Post] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isFetchingMore: Bool = false
    @Published private(set) var error: AppError?

    // Exposed publishers for ViewModels
    var timelinePostsPublisher: AnyPublisher<[Post], Never> { $currentTimelinePosts.eraseToAnyPublisher() }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }
    var isFetchingMorePublisher: AnyPublisher<Bool, Never> { $isFetchingMore.eraseToAnyPublisher() }
    var errorPublisher: AnyPublisher<AppError?, Never> { $error.eraseToAnyPublisher() }

    // MARK: - Init
    init(
        mastodonAPIService: MastodonAPIService,
        cacheService: CacheService,
        postActionService: PostActionService,
        locationManager: LocationManager,
        trendingService: TrendingService
    ) {
        self.mastodonAPIService = mastodonAPIService
        self.cacheService = cacheService
        self.postActionService = postActionService
        self.locationManager = locationManager
        self.trendingService = trendingService
        setupLocationListener()
    }

    // MARK: - Location Listener
    private func setupLocationListener() {
        locationManager.locationPublisher
            .debounce(for: .seconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] location in
                self?.logger.debug("Location updated: \(location)")
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Methods

    /// Home timeline (with optional pagination)
    // This is a duplicate of the one added to the protocol, ensure consistency or remove one.
    // For now, assuming this is the one to keep as it's implemented.
    // The protocol had (maxId: String?), this has (maxId: String? = nil). Default value is fine.
    func fetchHomeTimeline(maxId: String? = nil) async throws -> [Post] {
        logger.info("Fetching HOME timeline, maxId=\(maxId ?? "nil")")
        let posts = try await mastodonAPIService.fetchHomeTimeline(maxId: maxId)

        // Cache first page
        if maxId == nil, !posts.isEmpty {
            Task.detached { [cacheService] in
                await cacheService.cachePosts(posts, forKey: "timeline_home")
            }
        }
        return posts
    }

    /// Trending timeline
    // This is also in the protocol.
    func fetchTrendingTimeline() async throws -> [Post] {
        logger.info("Fetching TRENDING timeline")
        let posts = try await mastodonAPIService.fetchTrendingStatuses()

        // Cache results
        if !posts.isEmpty {
            Task.detached { [cacheService] in
                await cacheService.cachePosts(posts, forKey: "timeline_trending")
            }
        }
        return posts
    }

    /// Post context (ancestors & descendants)
    // This is also in the protocol.
    func fetchPostContext(postId: String) async throws -> PostContext {
        logger.info("Fetching context for post \(postId)")
        return try await mastodonAPIService.fetchPostContext(postId: postId)
    }

    // MARK: - Background Refresh

    func backgroundRefreshTimeline() async {
        isLoading = true
        do {
            let posts = try await fetchHomeTimeline()
            currentTimelinePosts = posts
            logger.info("Background refresh succeeded")
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
            self.error = AppError(message: "Failed to refresh timeline", underlyingError: error)
        }
        isLoading = false
    }


    // Required by TimelineServiceProtocol - if it's different from a method above, it needs implementation.
    // This seems to be a unique method name from the protocol.
    // If it's meant to be the same as fetchHomeTimeline, the protocol should match fetchHomeTimeline.
    // For now, I'll add a stub or point it to fetchHomeTimeline.
    // Assuming WorkspaceHomeTimeline is distinct or an alias for a specific fetch.
    // Let's assume it's an alias for fetchHomeTimeline for now.
    func WorkspaceHomeTimeline(maxId: String?, minId: String?, limit: Int?) async throws -> [Post] {
        // This protocol method seems to have more params than the class's fetchHomeTimeline.
        // For now, let's call the existing fetchHomeTimeline, ignoring minId and limit for simplicity,
        // as the class doesn't use them in its primary fetchHomeTimeline.
        // This might need further clarification based on actual usage of WorkspaceHomeTimeline.
        logger.info("WorkspaceHomeTimeline called, redirecting to fetchHomeTimeline with maxId: \(maxId ?? "nil")")
        // The MastodonAPIService.fetchHomeTimeline also takes minId and limit.
        // So, TimelineService.fetchHomeTimeline should ideally take them too if it's to be flexible.
        // Or, MastodonAPIService.fetchHomeTimeline is called directly by TimelineService, adapting parameters.
        return try await mastodonAPIService.fetchHomeTimeline(maxId: maxId, minId: minId, limit: limit)
    }

    // MARK: - Post Actions

    func toggleLike(for post: Post) async throws {
        _ = try await postActionService.toggleLike(postID: post.id)
    }

    func toggleRepost(for post: Post) async throws {
        _ = try await postActionService.toggleRepost(postID: post.id)
    }

    func comment(on post: Post, content: String) async throws {
        _ = try await postActionService.comment(postID: post.id, content: content)
    }
}
