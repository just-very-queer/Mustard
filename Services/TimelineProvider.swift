//
//  TimelineProvider.swift
//  Mustard
//
//  Created by Jules on 30/07/25.
//

import Foundation
import SwiftUI
import OSLog

// Define the filter enum here so it can be used by both the provider and views.
enum TimelineFilter: String, CaseIterable, Identifiable {
    case recommended = "For You"
    case latest = "Latest"
    case trending = "Trending"

    var id: String { self.rawValue }
}

@Observable
@MainActor
final class TimelineProvider {

    // MARK: - Published Properties
    private(set) var posts: [Post] = []
    private(set) var topPosts: [Post] = []
    private(set) var recommendedForYouPosts: [Post] = []
    private(set) var recommendedChronologicalPosts: [Post] = []

    private(set) var isLoading = false
    private(set) var isFetchingMore = false
    var alertError: AppError?

    // MARK: - Pagination State
    private var nextPageInfo: String?
    private var canLoadMoreLatest = true
    private var canLoadMoreRecommended = true
    private var recommendedMaxID: String?

    // MARK: - Services
    private let timelineService: TimelineService
    private let trendingService: TrendingService
    private let recommendationService: RecommendationService
    private let mastodonAPIService: MastodonAPIServiceProtocol

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineProvider")
    private var hasLoadedLatestOnce = false
    private var hasLoadedTrendingOnce = false

    // MARK: - Initialization
    init(
        timelineService: TimelineService,
        trendingService: TrendingService,
        recommendationService: RecommendationService,
        mastodonAPIService: MastodonAPIServiceProtocol
    ) {
        self.timelineService = timelineService
        self.trendingService = trendingService
        self.recommendationService = recommendationService
        self.mastodonAPIService = mastodonAPIService
    }

    // MARK: - Data Fetching

    func refreshTimeline(for filter: TimelineFilter) async {
        await initializeTimelineData(for: filter)
    }

    func initializeTimelineData(for filter: TimelineFilter) async {
        guard !isLoading else { return }
        isLoading = true
        alertError = nil

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

    func fetchMoreTimeline(for filter: TimelineFilter) async {
        guard !isLoading, !isFetchingMore else { return }
        isFetchingMore = true
        alertError = nil

        switch filter {
        case .recommended:
            await fetchMoreRecommended()
        case .latest:
            await fetchMoreLatest()
        case .trending:
            // Trending timeline usually doesn't paginate this way
            break
        }

        isFetchingMore = false
    }

    private func loadRecommendedTimelineInitial() async {
        recommendedMaxID = nil
        canLoadMoreRecommended = true
        alertError = nil

        do {
            logger.info("Loading initial 'For You' timeline.")
            let recommendedPostIDs = await recommendationService.topRecommendations(limit: 50)

            guard !recommendedPostIDs.isEmpty else {
                logger.info("No recommended post IDs received.")
                self.recommendedForYouPosts = []
                self.posts = []
                self.canLoadMoreRecommended = false
                await fetchTopPostsForHeader()
                return
            }

            let fetchedPosts = try await mastodonAPIService.fetchStatuses(by_ids: recommendedPostIDs)
            self.recommendedForYouPosts = fetchedPosts
            self.posts = fetchedPosts

            if fetchedPosts.count < 50 {
                canLoadMoreRecommended = false
            }

            await fetchTopPostsForHeader()

        } catch {
            logger.error("Error loading recommended timeline: \(error.localizedDescription)")
            handleFetchError(error)
        }
    }

    private func loadLatestTimelineInitial() async {
        nextPageInfo = nil
        canLoadMoreLatest = true
        alertError = nil

        do {
            let latestPosts = try await timelineService.fetchHomeTimeline(maxId: nil)
            self.posts = latestPosts
            self.nextPageInfo = latestPosts.last?.id
            await fetchTopPostsForHeader()
            hasLoadedLatestOnce = true
        } catch {
            handleFetchError(error)
        }
    }

    private func loadTrendingTimeline() async {
        do {
            self.posts = try await timelineService.fetchTrendingTimeline()
            self.nextPageInfo = nil
            self.topPosts = try await trendingService.fetchTrendingPosts()
            hasLoadedTrendingOnce = true
        } catch {
            handleFetchError(error)
        }
    }

    private func fetchMoreRecommended() async {
        guard canLoadMoreRecommended else { return }
        do {
            let olderPosts = try await timelineService.fetchHomeTimeline(maxId: recommendedMaxID)
            if !olderPosts.isEmpty {
                recommendedChronologicalPosts.append(contentsOf: olderPosts)
                recommendedMaxID = olderPosts.last?.id
                if olderPosts.count < 20 { canLoadMoreRecommended = false }

                recommendedForYouPosts = await recommendationService.scoredTimeline(recommendedChronologicalPosts)
                posts = recommendedForYouPosts
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
            let morePosts = try await timelineService.fetchHomeTimeline(maxId: pageInfo)
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

    private func fetchTopPostsForHeader() async {
        do {
            topPosts = try await trendingService.fetchTrendingPosts()
        } catch {
            logger.error("Failed to fetch top posts: \(error.localizedDescription)")
            topPosts = []
        }
    }

    private func handleFetchError(_ error: Error) {
        if (error as? URLError)?.code == .cancelled {
            logger.info("Timeline fetch cancelled.")
            return
        }
        alertError = AppError(message: "Failed to load timeline", underlyingError: error)
        posts = []
    }

    // MARK: - Context Fetching

    func fetchContext(for post: Post) async -> PostContext? {
        logger.debug("Fetching context for post ID: \(post.id)")
        do {
            let context = try await timelineService.fetchPostContext(postId: post.id)
            return context
        } catch {
            logger.error("Failed to fetch context for post ID \(post.id): \(error.localizedDescription)")
            return nil
        }
    }
}
