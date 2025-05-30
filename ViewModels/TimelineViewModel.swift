//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//  (REVISED: Merged RecommendedTimelineViewModel functionality)
//

import Foundation
import Combine
import CoreLocation
import SwiftUI
import OSLog
import SwiftData

@MainActor
final class TimelineViewModel: ObservableObject {
    
    // MARK: - Filter Enum
    enum TimelineFilter: String, CaseIterable, Identifiable {
        case recommended = "For You"  // Personalized, scored timeline
        case latest = "Latest"        // Standard home timeline
        case trending = "Trending"    // Trending posts
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Published Properties
    @Published private(set) var posts: [Post] = [] // Posts shown for selectedFilter (for recommended and latest)
    @Published private(set) var topPosts: [Post] = [] // For horizontal trending header
    
    // Recommended timeline holds its own lists for scoring and fallback chronological
    @Published private(set) var recommendedForYouPosts: [Post] = []
    @Published private(set) var recommendedChronologicalPosts: [Post] = []
    
    @Published var selectedFilter: TimelineFilter = .recommended {
        didSet {
            if oldValue != self.selectedFilter {
                logger.info("Filter changed to \(self.selectedFilter.rawValue). Refreshing data.")
                self.posts = []
                self.nextPageInfo = nil
                self.canLoadMoreRecommended = true
                self.canLoadMoreLatest = true
                Task { await self.initializeTimelineData() }
            }
        }
    }
    
    @Published private(set) var isLoading = false
    @Published private(set) var isFetchingMore = false
    @Published var alertError: AppError?
    @Published var navigationPath = NavigationPath()
    
    // Post actions required by PostViewActionsDelegate - mark them as @Published to satisfy protocol
    @Published var selectedPostForComments: Post?
    @Published var showingCommentSheet = false
    @Published var commentText: String = ""
    @Published private(set) var postLoadingStates: [String: Bool] = [:]
    
    // MARK: - Pagination State
    private var nextPageInfo: String?               // For Latest and Recommended chronological
    private var canLoadMoreLatest = true
    private var canLoadMoreRecommended = true
    private var recommendedMaxID: String?            // For pagination of recommended chronological
    
    // MARK: - Services
    private let timelineService: TimelineService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private let trendingService: TrendingService
    private let cacheService: CacheService
    internal let recommendationService: RecommendationService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineViewModel")
    
    // Placeholder for current user account ID - replace with real auth logic as needed
    internal var currentUserAccountID: String? = "USER_ID_PLACEHOLDER"
    
    // MARK: - Initialization
    init(
        timelineService: TimelineService,
        locationManager: LocationManager,
        trendingService: TrendingService,
        postActionService: PostActionService,
        cacheService: CacheService,
        recommendationService: RecommendationService
    ) {
        self.timelineService = timelineService
        self.locationManager = locationManager
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.cacheService = cacheService
        self.recommendationService = recommendationService
    }
    
    // MARK: - Data Fetching
    
    /// Initialize timeline data based on selected filter.
    func initializeTimelineData() async {
        guard !isLoading else { return }
        isLoading = true
        alertError = nil
        
        switch selectedFilter {
        case .recommended:
            await loadRecommendedTimelineInitial()
        case .latest:
            await loadLatestTimelineInitial()
        case .trending:
            await loadTrendingTimeline()
        }
        
        isLoading = false
    }
    
    private func loadRecommendedTimelineInitial() async {
        recommendedMaxID = nil
        canLoadMoreRecommended = true
        alertError = nil
        
        do {
            // Fetch chronological posts for recommended
            let chronological = try await timelineService.fetchHomeTimeline(maxId: nil)
            recommendedChronologicalPosts = chronological
            recommendedMaxID = chronological.last?.id
            // API usually returns 20 items by default. Check against that.
            if chronological.count < 20 {
                canLoadMoreRecommended = false
            }
            
            // Score posts for "For You"
            recommendedForYouPosts = await recommendationService.scoredTimeline(chronological)
            posts = recommendedForYouPosts
            
            initializeLoadingStates(for: posts)
            await fetchTopPostsForHeader()
        } catch {
            handleFetchError(error)
            posts = []
            recommendedForYouPosts = []
            recommendedChronologicalPosts = []
        }
    }
    
    private func loadLatestTimelineInitial() async {
        nextPageInfo = nil
        canLoadMoreLatest = true
        alertError = nil
        
        do {
            let latestPosts = try await timelineService.fetchHomeTimeline(maxId: nil)
            posts = latestPosts
            nextPageInfo = latestPosts.last?.id
            initializeLoadingStates(for: posts)
            await fetchTopPostsForHeader()
        } catch {
            handleFetchError(error)
            posts = []
        }
    }
    
    private func loadTrendingTimeline() async {
        do {
            posts = try await timelineService.fetchTrendingTimeline()
            nextPageInfo = nil
            initializeLoadingStates(for: posts)
            topPosts = try await trendingService.fetchTrendingPosts()
        } catch {
            handleFetchError(error)
            posts = []
            topPosts = []
        }
    }
    
    /// Fetch more posts for pagination.
    func fetchMoreTimeline() async {
        guard !isLoading, !isFetchingMore else { return }
        isFetchingMore = true
        alertError = nil
        
        switch selectedFilter {
        case .recommended:
            await fetchMoreRecommended()
        case .latest:
            await fetchMoreLatest()
        case .trending:
            isFetchingMore = false
            return
        }
        
        isFetchingMore = false
    }
    
    private func fetchMoreRecommended() async {
        guard canLoadMoreRecommended else { return }
        do {
            let olderPosts = try await timelineService.fetchHomeTimeline(maxId: recommendedMaxID)
            if !olderPosts.isEmpty {
                recommendedChronologicalPosts.append(contentsOf: olderPosts)
                recommendedMaxID = olderPosts.last?.id
                if olderPosts.count < 20 {
                    canLoadMoreRecommended = false
                }
                // Re-score entire list
                recommendedForYouPosts = await recommendationService.scoredTimeline(recommendedChronologicalPosts)
                posts = recommendedForYouPosts
                initializeLoadingStates(for: posts)
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
                initializeLoadingStates(for: morePosts)
            } else {
                canLoadMoreLatest = false
                nextPageInfo = nil
            }
        } catch {
            handleFetchError(error)
        }
    }
    
    func refreshTimeline() async {
        await initializeTimelineData()
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
    
    // MARK: - Post Actions
    
    func toggleLike(for post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        
        // Store original values for potential revert
        let originalIsFavourited = posts[index].isFavourited
        let originalFavouritesCount = posts[index].favouritesCount

        // Optimistic update
        posts[index].isFavourited.toggle()
        posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
        
        // Explicitly signal change to SwiftUI for the main posts array
        let updatedPostForUIMain = posts[index]
        posts[index] = updatedPostForUIMain

        if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
            // Optimistic update for topPosts
            topPosts[topIndex].isFavourited = posts[index].isFavourited
            topPosts[topIndex].favouritesCount = posts[index].favouritesCount
            // Explicitly signal change to SwiftUI for the topPosts array
            let updatedPostForUITop = topPosts[topIndex]
            topPosts[topIndex] = updatedPostForUITop
        }
        
        updateLoadingState(for: post.id, isLoading: true)
        
        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleLike(postID: post.id)
                if let updated = returnedPost {
                    updatePostInAllLists(updated)
                }
                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: posts[index].isFavourited ? InteractionType.like : InteractionType.unlike,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleLike: \(error.localizedDescription)")
                // Revert optimistic update
                posts[index].isFavourited = originalIsFavourited
                posts[index].favouritesCount = originalFavouritesCount
                let revertedPostForUIMain = posts[index]
                posts[index] = revertedPostForUIMain

                if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
                    topPosts[topIndex].isFavourited = originalIsFavourited
                    topPosts[topIndex].favouritesCount = originalFavouritesCount
                    let revertedPostForUITop = topPosts[topIndex]
                    topPosts[topIndex] = revertedPostForUITop
                }
                alertError = AppError(message: "Failed to like post", underlyingError: error)
            }
        }
    }
    
    func toggleRepost(for post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        
        // Store original values for potential revert
        let originalIsReblogged = posts[index].isReblogged
        let originalReblogsCount = posts[index].reblogsCount

        // Optimistic update
        posts[index].isReblogged.toggle()
        posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
        
        // Explicitly signal change to SwiftUI for the main posts array
        let updatedPostForUIMain = posts[index]
        posts[index] = updatedPostForUIMain

        if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
            // Optimistic update for topPosts
            topPosts[topIndex].isReblogged = posts[index].isReblogged
            topPosts[topIndex].reblogsCount = posts[index].reblogsCount
            // Explicitly signal change to SwiftUI for the topPosts array
            let updatedPostForUITop = topPosts[topIndex]
            topPosts[topIndex] = updatedPostForUITop
        }
        
        updateLoadingState(for: post.id, isLoading: true)
        
        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleRepost(postID: post.id)
                if let updated = returnedPost {
                    updatePostInAllLists(updated)
                }
                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: posts[index].isReblogged ? InteractionType.repost : InteractionType.unrepost,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleRepost: \(error.localizedDescription)")
                // Revert optimistic update
                posts[index].isReblogged = originalIsReblogged
                posts[index].reblogsCount = originalReblogsCount
                let revertedPostForUIMain = posts[index]
                posts[index] = revertedPostForUIMain

                if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
                    topPosts[topIndex].isReblogged = originalIsReblogged
                    topPosts[topIndex].reblogsCount = originalReblogsCount
                    let revertedPostForUITop = topPosts[topIndex]
                    topPosts[topIndex] = revertedPostForUITop
                }
                alertError = AppError(message: "Failed to repost", underlyingError: error)
            }
        }
    }
    
    func comment(on post: Post, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Store original replies count for potential revert (though less critical as it's just a count)
        var originalRepliesCountMain: Int?
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            originalRepliesCountMain = posts[index].repliesCount
        }
        var originalRepliesCountTop: Int?
        if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
            originalRepliesCountTop = topPosts[topIndex].repliesCount
        }

        updateLoadingState(for: post.id, isLoading: true)
        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                _ = try await postActionService.comment(postID: post.id, content: content)

                // Optimistic update for repliesCount
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].repliesCount += 1
                    let updatedPostForUIMain = posts[index]
                    posts[index] = updatedPostForUIMain
                }
                if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }) {
                    topPosts[topIndex].repliesCount += 1
                    let updatedPostForUITop = topPosts[topIndex]
                    topPosts[topIndex] = updatedPostForUITop
                }
                
                commentText = ""
                showingCommentSheet = false
                selectedPostForComments = nil
                
                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: InteractionType.comment,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed to post comment: \(error.localizedDescription)")
                // Revert optimistic update for repliesCount if originalRepliesCount was captured
                if let index = posts.firstIndex(where: { $0.id == post.id }), let originalCount = originalRepliesCountMain {
                    posts[index].repliesCount = originalCount
                    let revertedPostForUIMain = posts[index]
                    posts[index] = revertedPostForUIMain
                }
                if let topIndex = topPosts.firstIndex(where: { $0.id == post.id }), let originalCount = originalRepliesCountTop {
                    topPosts[topIndex].repliesCount = originalCount
                    let revertedPostForUITop = topPosts[topIndex]
                    topPosts[topIndex] = revertedPostForUITop
                }
                alertError = AppError(message: "Failed to post comment", underlyingError: error)
            }
        }
    }
    
    func showComments(for post: Post) {
        selectedPostForComments = post
        showingCommentSheet = true
    }
    
    // MARK: - Loading State Management
    
    private func initializeLoadingStates(for newPosts: [Post]) {
        var newStates = postLoadingStates
        for post in newPosts where newStates[post.id] == nil {
            newStates[post.id] = false
        }
        postLoadingStates = newStates
    }
    
    func isLoading(for post: Post) -> Bool {
        postLoadingStates[post.id] ?? false
    }
    
    private func updateLoadingState(for postId: String, isLoading: Bool) {
        postLoadingStates[postId] = isLoading
    }
    
    // MARK: - Helper to update posts in all lists
    
    private func updatePostInAllLists(_ updatedPost: Post) {
        if let idx = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[idx] = updatedPost
        }
        if let topIdx = topPosts.firstIndex(where: { $0.id == updatedPost.id }) {
            topPosts[topIdx] = updatedPost
        }
        if let recForYouIdx = recommendedForYouPosts.firstIndex(where: { $0.id == updatedPost.id }) {
            recommendedForYouPosts[recForYouIdx] = updatedPost
        }
        if let recChronoIdx = recommendedChronologicalPosts.firstIndex(where: { $0.id == updatedPost.id }) {
            recommendedChronologicalPosts[recChronoIdx] = updatedPost
        }
    }
    
    // MARK: - Navigation
    
    func navigateToProfile(_ user: User) {
        navigationPath.append(user)
    }
    
    func navigateToDetail(for post: Post) {
        navigationPath.append(post)
    }
}
