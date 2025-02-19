//  TimelineService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog
import CoreLocation
import Combine

class TimelineService {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private let trendingService: TrendingService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineService")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers
    @Published private(set) var timelinePosts: [Post] = []
    var timelinePostsPublisher: Published<[Post]>.Publisher { $timelinePosts }

    @Published private(set) var isLoading: Bool = false
    var isLoadingPublisher: Published<Bool>.Publisher { $isLoading }

    @Published private(set) var isFetchingMore: Bool = false
    var isFetchingMorePublisher: Published<Bool>.Publisher { $isFetchingMore }

    @Published private(set) var error: AppError?
    var errorPublisher: Published<AppError?>.Publisher { $error }

    @Published private(set) var topPosts: [Post] = []

    init(
        networkService: NetworkService,
        cacheService: CacheService,
        postActionService: PostActionService,
        locationManager: LocationManager,
        trendingService: TrendingService
    ) {
        self.networkService = networkService
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
                guard let self = self else { return }
                self.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        print("Location updated: \(location)")
    }

    // MARK: - Timeline Data Methods
    func initializeTimelineData() {
        isLoading = true
        Task {
            do {
                let posts = try await fetchTimeline(useCache: true)
                await MainActor.run {
                    self.timelinePosts = posts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(
                        message: "Failed to initialize timeline.",
                        underlyingError: error
                    )
                    self.isLoading = false
                }
                logger.error("Initialize timeline error: \(error.localizedDescription)")
            }
        }
    }

    func fetchMoreTimelinePosts() {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        
        Task {
            do {
                let newPosts = try await fetchMoreTimeline()
                await MainActor.run {
                    if !newPosts.isEmpty {
                        self.timelinePosts.append(contentsOf: newPosts)
                    }
                    self.isFetchingMore = false
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(
                        message: "Failed to fetch more posts",
                        underlyingError: error
                    )
                    self.isFetchingMore = false
                }
                logger.error("Fetch more error: \(error.localizedDescription)")
            }
        }
    }

    func refreshTimeline() {
        Task {
            do {
                let posts = try await fetchTimeline(useCache: false)
                await MainActor.run {
                    self.timelinePosts = posts
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(
                        message: "Refresh failed",
                        underlyingError: error
                    )
                }
                logger.error("Refresh error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Network Operations
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        let cacheKey = "timeline"
        
        if useCache {
            let cachedPosts = await cacheService.loadPostsFromCache(forKey: cacheKey)
            
            // Check if we have cached posts
            if !cachedPosts.isEmpty {
                logger.info("Loaded \(cachedPosts.count) posts from cache")
                return cachedPosts
            }
            
            logger.info("Empty cache, falling back to network")
        }

        // Proceed with fetching from network if cache is empty or not used
        do {
            let fetchedPosts = try await networkService.request(
                endpoint: "/api/v1/timelines/home",
                method: .get,
                responseType: [Post].self
            )
            
            // Cache the fetched posts for future use
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
                logger.info("Cached \(fetchedPosts.count) posts")
            }
            
            return fetchedPosts
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchMoreTimeline() async throws -> [Post] {
        var endpoint = "/api/v1/timelines/home"
        
        if let lastPostID = timelinePosts.last?.id {
            endpoint += "?max_id=\(lastPostID)"
        }

        let fetchedPosts = try await networkService.request(
            endpoint: endpoint,
            method: .get,
            responseType: [Post].self
        )

        if !fetchedPosts.isEmpty {
            Task {
                let updatedPosts = self.timelinePosts + fetchedPosts
                await cacheService.cachePosts(updatedPosts, forKey: "timeline")
                logger.info("Updated cache with \(fetchedPosts.count) new posts")
            }
        }
        
        return fetchedPosts
    }

    func fetchPosts(page: Int) async -> [Post] {
        var endpoint = "/api/v1/timelines/home"

        // Use max_id for pagination instead of page number for pages > 1
        // Assuming timelinePosts is accessible within this scope and holds the currently loaded posts
        // and assuming posts are ordered with newest first, so last post is the oldest currently loaded
        // NOTE: You need to have `timelinePosts` defined and maintained in your TimelineService or TimelineViewModel
        // For example:  @Published var timelinePosts: [Post] = [] in your TimelineViewModel
        // and append fetchedPosts to timelinePosts in your viewModel when using this fetchPosts function.
        // This function ONLY handles fetching and caching, not updating the viewModel's timelinePosts directly.

        // Check if page is greater than 1 and if there are existing timeline posts to get the last post's id
        // to use as max_id for pagination.
        // Important: make sure timelinePosts is populated BEFORE calling fetchPosts with page > 1,
        // otherwise lastPostID will be nil, and pagination might not work as expected.
        // You should fetch page 1 first to initialize timelinePosts.
        if page > 1, !timelinePosts.isEmpty, let lastPost = timelinePosts.last {
            endpoint += "?max_id=\(lastPost.id)"
        } else {
            endpoint += "?page=\(page)" // Fallback to page based if it's the first page (or timelinePosts is not available for max_id)
        }


        do {
            let fetchedPosts = try await networkService.request(
                endpoint: endpoint,
                method: .get,
                responseType: [Post].self
            )

            // Cache new posts for better performance
            if !fetchedPosts.isEmpty {
                Task {
                    // Assuming cacheService and cachePosts are available
                    // and assuming timelinePosts is already available and contains previously fetched posts.
                    // CAUTION: This cache update logic ASSUMES timelinePosts is the CURRENT SOURCE OF TRUTH
                    // and you intend to APPEND the newly fetched posts to the existing timelinePosts for caching.
                    // If you intend to REPLACE the cache with ONLY the newly fetched posts, you should adjust this logic.

                    // Correct way to update cache by appending fetchedPosts to the EXISTING timelinePosts.
                    // This assumes timelinePosts contains the posts already loaded in the current session.
                    let updatedPosts = timelinePosts + fetchedPosts // Append new posts to existing ones
                    await cacheService.cachePosts(updatedPosts, forKey: "timeline") // Cache the combined list
                    logger.info("Updated cache with \(fetchedPosts.count) new posts, total cached: \(updatedPosts.count)")
                }
            }

            return fetchedPosts
        } catch {
            logger.error("Fetch posts error (page \(page)): \(error.localizedDescription)")
            return [] // Return an empty array on failure
        }
    }

    func backgroundRefreshTimeline() async throws {
        do {
            let fetchedPosts = try await networkService.request(
                endpoint: "/api/v1/timelines/home",
                method: .get,
                responseType: [Post].self
            )
            
            await MainActor.run {
                self.timelinePosts = fetchedPosts
            }
            
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: "timeline")
                logger.info("Background refresh cached \(fetchedPosts.count) posts")
            }
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Post Actions
    // Toggle like on a post
    func toggleLike(for post: Post) async throws {
        try await postActionService.toggleLike(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isFavourited.toggle()
            post.favouritesCount += post.isFavourited ? 1 : -1
        }
    }

    // Toggle repost on a post
    func toggleRepost(for post: Post) async throws {
        try await postActionService.toggleRepost(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isReblogged.toggle()
            post.reblogsCount += post.isReblogged ? 1 : -1
        }
    }

    // Comment on a post
    func comment(on post: Post, content: String) async throws {
        try await postActionService.comment(postID: post.id, content: content)
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == post.id }) {
                timelinePosts[index].repliesCount += 1
            }
        }
    }

    // Update post interaction (like/repost) in the timeline
    private func updatePostInteraction(for postID: String, update: (inout Post) -> Void) async {
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == postID }) {
                var post = timelinePosts[index]
                update(&post)
                timelinePosts[index] = post
            }
        }
    }

    // Fetch top posts (e.g., trending posts)
    func fetchTopPosts() async {
        do {
            let trendingPosts = try await trendingService.fetchTopPosts()
            await MainActor.run {
                self.topPosts = trendingPosts
            }
        } catch {
            await MainActor.run {
                self.error = AppError(
                    message: "Top posts fetch failed",
                    underlyingError: error
                )
            }
            logger.error("Top posts error: \(error.localizedDescription)")
        }
    }
}

