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
class TimelineService {
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
