//
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

    @Published private(set)  var isLoading: Bool = false
    var isLoadingPublisher: Published<Bool>.Publisher { $isLoading }

    @Published private(set) var isFetchingMore: Bool = false
    var isFetchingMorePublisher: Published<Bool>.Publisher { $isFetchingMore }

    @Published private(set) var error: AppError?
    var errorPublisher: Published<AppError?>.Publisher { $error }

    @Published private(set) var topPosts: [Post] = []  // Make sure this is a property and not a method

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
                self.handleLocationUpdate(location) // Call the new method to handle location updates
            }
            .store(in: &cancellables)
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        // Handle the location update logic here
        print("Location updated: \(location)")
    }
    
    // MARK: - Timeline Data Methods
    func initializeTimelineData() {
        isLoading = true
        Task {
            do {
                let posts = try await fetchTimeline(useCache: true)
                if posts.isEmpty {
                    // If no posts were found in cache, fetch from network
                    throw AppError(message: "No cached posts found, fetching from network", underlyingError: nil)
                }
                await MainActor.run {
                    self.timelinePosts = posts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(message: "Failed to initialize timeline data.", underlyingError: error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func fetchMoreTimelinePosts() {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        let nextPage = (timelinePosts.count / 20) + 1
        Task {
            do {
                let newPosts = try await fetchMoreTimeline(page: nextPage)
                await MainActor.run {
                    if !newPosts.isEmpty {
                        self.timelinePosts.append(contentsOf: newPosts)
                    }
                    self.isFetchingMore = false
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(message: "Failed to fetch more timeline posts.", underlyingError: error)
                    self.isFetchingMore = false
                }
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
                    self.error = error as? AppError ?? AppError(message: "Failed to refresh timeline.", underlyingError: error)
                }
            }
        }
    }

    // MARK: - Network Operations
    
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        let cacheKey = "timeline"
        if useCache {
            do {
                // Check if the cache exists and can be loaded
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: cacheKey)
                return cachedPosts
            } catch let error as AppError {
                if case .mastodon(.cacheNotFound) = error.type { // Check for specific cache not found error
                    logger.info("Timeline cache not found. Fetching from network.")
                    // Proceed to fetch from network below
                } else {
                    logger.error("Cache error: \(error.localizedDescription)")
                    throw error // Re-throw other cache errors
                }
            }
        }

        // Fetch from the network (this part was already there, just moved here)
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            // Cache the posts after fetching from the network
            Task { await cacheService.cachePosts(fetchedPosts, forKey: cacheKey) }
            return fetchedPosts
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw error // Re-throw network errors
        }
    }

    func fetchMoreTimeline(page: Int) async throws -> [Post] {
        var endpoint = "/api/v1/timelines/home"
        if page > 1 {
            do {
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: "timeline")
                if let lastID = cachedPosts.last?.id {
                    endpoint += "?max_id=\(lastID)"
                }
            } catch {
                logger.error("Cache error: \(error.localizedDescription)")
            }
        }

        let url = try await NetworkService.shared.endpointURL(endpoint)
        let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

        if !fetchedPosts.isEmpty {
            Task {
                do {
                    let updatedPosts = (try await cacheService.loadPostsFromCache(forKey: "timeline")) + fetchedPosts
                    await cacheService.cachePosts(updatedPosts, forKey: "timeline")
                } catch {
                    logger.error("Cache update error: \(error.localizedDescription)")
                }
            }
        }
        return fetchedPosts
    }

    func backgroundRefreshTimeline() async throws {
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            Task { await cacheService.cachePosts(fetchedPosts, forKey: "timeline") }
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Post Actions
    func toggleLike(for post: Post) async throws {
        try await postActionService.toggleLike(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isFavourited.toggle()
            post.favouritesCount += post.isFavourited ? 1 : -1
        }
    }

    func toggleRepost(for post: Post) async throws {
        try await postActionService.toggleRepost(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isReblogged.toggle()
            post.reblogsCount += post.isReblogged ? 1 : -1
        }
    }

    func comment(on post: Post, content: String) async throws {
        try await postActionService.comment(postID: post.id, content: content)
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == post.id }) {
                timelinePosts[index].repliesCount += 1
            }
        }
    }
    
    func fetchTopPosts() async {
        do {
            let trendingPosts = try await trendingService.fetchTopPosts()
            await MainActor.run {
                self.topPosts = trendingPosts
            }
        } catch {
            logger.error("Failed to fetch top posts: \(error.localizedDescription)")
            await MainActor.run {
                self.error = AppError(message: "Failed to fetch top posts", underlyingError: error)
            }
        }
    }

    private func updatePostInteraction(for postID: String, update: (inout Post) -> Void) async {
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == postID }) {
                var post = timelinePosts[index]
                update(&post)
                timelinePosts[index] = post
            }
        }
    }
}


