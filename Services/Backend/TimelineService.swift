//
//  TimelineService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Consolidated Timeline Feed & State Manager
//

import Foundation
import OSLog
import Observation

// MARK: - TimelineFilter Enum

enum TimelineFilter: String, CaseIterable, Identifiable {
    case recommended = "For You"
    case latest = "Latest"
    case trending = "Trending"

    var id: String { self.rawValue }
}

@Observable
@MainActor
class TimelineService {
    // MARK: - Dependencies
    private let mastodonAPIService: MastodonAPIService
    private let postActionService: PostActionService
    private let trendingService: TrendingService
    private let recommendationService: RecommendationService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineService")

    // MARK: - Published State
    private(set) var posts: [Post] = []
    private(set) var topPosts: [Post] = []
    private(set) var recommendedChronologicalPosts: [Post] = []

    private(set) var isLoading: Bool = false
    private(set) var isFetchingMore: Bool = false
    var error: AppError?

    // MARK: - Pagination State
    private var nextPageInfo: String?
    private var canLoadMoreLatest = true
    private var canLoadMoreRecommended = true
    private var recommendedMaxID: String?

    // MARK: - Init
    init(
        mastodonAPIService: MastodonAPIService,
        postActionService: PostActionService,
        trendingService: TrendingService,
        recommendationService: RecommendationService
    ) {
        self.mastodonAPIService = mastodonAPIService
        self.postActionService = postActionService
        self.trendingService = trendingService
        self.recommendationService = recommendationService
    }

    // MARK: - Public Feed Interface

    func initializeTimelineData(for filter: TimelineFilter) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        switch filter {
        case .recommended:
            await loadRecommendedTimelineInitial()
        case .latest:
            await loadLatestTimelineInitial()
        case .trending:
            await loadTrendingTimeline()
        }

        isLoading = false
    }

    func refreshTimeline(for filter: TimelineFilter) async {
        await initializeTimelineData(for: filter)
    }

    func fetchMoreTimeline(for filter: TimelineFilter) async {
        guard !isLoading, !isFetchingMore else { return }
        isFetchingMore = true
        error = nil

        switch filter {
        case .recommended:
            await fetchMoreRecommended()
        case .latest:
            await fetchMoreLatest()
        case .trending:
            break
        }

        isFetchingMore = false
    }

    // MARK: - Internal Loaders

    private func loadRecommendedTimelineInitial() async {
        recommendedMaxID = nil
        canLoadMoreRecommended = true

        do {
            logger.info("Loading initial 'For You' timeline...")
            let recommendedPostIDs = await recommendationService.topRecommendations(limit: 50)

            if !recommendedPostIDs.isEmpty {
                let fetchedPosts = try await mastodonAPIService.fetchStatuses(by_ids: recommendedPostIDs)
                self.posts = fetchedPosts
                if fetchedPosts.count < 50 { canLoadMoreRecommended = false }
            } else {
                // Fallback to home timeline scored by affinity
                let homePosts = try await fetchHomeTimeline()
                self.recommendedChronologicalPosts = homePosts
                self.posts = await recommendationService.scoredTimeline(homePosts)
                self.recommendedMaxID = homePosts.last?.id
            }

            await fetchTopPostsHeader()
        } catch {
            logger.error("Error loading recommended timeline: \(error.localizedDescription)")
            handleFetchError(error)
        }
    }

    private func loadLatestTimelineInitial() async {
        nextPageInfo = nil
        canLoadMoreLatest = true

        do {
            let latestPosts = try await fetchHomeTimeline(maxId: nil)
            self.posts = latestPosts
            self.nextPageInfo = latestPosts.last?.id
            await fetchTopPostsHeader()
        } catch {
            handleFetchError(error)
        }
    }

    private func loadTrendingTimeline() async {
        do {
            self.posts = try await fetchTrendingTimeline()
            self.nextPageInfo = nil
            self.topPosts = try await trendingService.fetchTrendingPosts()
        } catch {
            handleFetchError(error)
        }
    }

    private func fetchMoreRecommended() async {
        guard canLoadMoreRecommended else { return }
        do {
            let olderPosts = try await fetchHomeTimeline(maxId: recommendedMaxID)
            if !olderPosts.isEmpty {
                recommendedChronologicalPosts.append(contentsOf: olderPosts)
                recommendedMaxID = olderPosts.last?.id
                if olderPosts.count < 20 { canLoadMoreRecommended = false }
                posts = await recommendationService.scoredTimeline(recommendedChronologicalPosts)
            } else {
                canLoadMoreRecommended = false
            }
        } catch {
            handleFetchError(error)
        }
    }

    private func fetchMoreLatest() async {
        guard canLoadMoreLatest, let pageInfo = nextPageInfo else { return }
        do {
            let morePosts = try await fetchHomeTimeline(maxId: pageInfo)
            if !morePosts.isEmpty {
                posts.append(contentsOf: morePosts)
                nextPageInfo = morePosts.last?.id
            } else {
                canLoadMoreLatest = false
                nextPageInfo = nil
            }
        } catch {
            handleFetchError(error)
        }
    }

    private func fetchTopPostsHeader() async {
        do {
            topPosts = try await trendingService.fetchTrendingPosts()
        } catch {
            logger.error("Failed to fetch top trending posts: \(error.localizedDescription)")
            topPosts = []
        }
    }

    private func handleFetchError(_ error: Error) {
        if (error as? URLError)?.code == .cancelled { return }
        self.error = AppError(message: "Failed to load timeline", underlyingError: error)
        self.posts = []
    }

    // MARK: - Direct Mastodon API Calls

    func fetchHomeTimeline(maxId: String? = nil, limit: Int = 20) async throws -> [Post] {
        return try await mastodonAPIService.fetchHomeTimeline(maxId: maxId, limit: limit)
    }

    func fetchTrendingTimeline() async throws -> [Post] {
        return try await mastodonAPIService.fetchTrendingStatuses()
    }

    func fetchPostContext(postId: String) async throws -> PostContext {
        return try await mastodonAPIService.fetchPostContext(postId: postId)
    }

    func fetchContext(for post: Post) async -> PostContext? {
        do {
            return try await fetchPostContext(postId: post.id)
        } catch {
            return nil
        }
    }

    // MARK: - Post Actions Delegate

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
