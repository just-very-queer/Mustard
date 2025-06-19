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
    private let mastodonAPIService: MastodonAPIServiceProtocol // Added MastodonAPIService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineViewModel")
    
    // Flags for lazy loading non-default timelines
    private var hasLoadedLatestOnce = false
    private var hasLoadedTrendingOnce = false

    // Placeholder for current user account ID - replace with real auth logic as needed
    internal var currentUserAccountID: String? = "USER_ID_PLACEHOLDER"
    
    // MARK: - Initialization
    init(
        timelineService: TimelineService,
        locationManager: LocationManager,
        trendingService: TrendingService,
        postActionService: PostActionService,
        cacheService: CacheService,
        recommendationService: RecommendationService,
        mastodonAPIService: MastodonAPIServiceProtocol = MastodonAPIService.shared // Added with default
    ) {
        self.timelineService = timelineService
        self.locationManager = locationManager
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.cacheService = cacheService
        self.recommendationService = recommendationService
        self.mastodonAPIService = mastodonAPIService // Initialize new service
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
        recommendedMaxID = nil // This might become obsolete or change for new "For You" pagination
        canLoadMoreRecommended = true // This will need re-evaluation based on new "For You" source
        alertError = nil
        
        do {
            logger.info("Loading initial 'For You' timeline using new recommendation flow.")

            // New logic: Fetch top recommended post IDs
            let recommendedPostIDs = await recommendationService.topRecommendations(limit: 50)

            guard !recommendedPostIDs.isEmpty else {
                logger.info("No recommended post IDs received. Clearing 'For You' timeline.")
                recommendedForYouPosts = []
                // recommendedChronologicalPosts = [] // Clearing this as its role is changing
                posts = []
                canLoadMoreRecommended = false // No IDs, so nothing more to load this way
                await fetchTopPostsForHeader() // Still fetch trending for header
                return
            }
            
            logger.info("Fetched \(recommendedPostIDs.count) recommended post IDs. Fetching full posts...")

            // Fetch full Post objects for these IDs
            let fetchedPosts = try await mastodonAPIService.fetchStatuses(by_ids: recommendedPostIDs)
            logger.info("Successfully fetched \(fetchedPosts.count) full posts for 'For You' timeline.")

            // The order from fetchStatuses might not match topRecommendations if the API doesn't preserve it.
            // If order is critical and not preserved by API, re-order here based on recommendedPostIDs.
            // For now, assume API returns them in a usable order or order isn't strictly enforced by ID list.
            recommendedForYouPosts = fetchedPosts
            posts = recommendedForYouPosts // Update the main posts array

            // Regarding recommendedChronologicalPosts:
            // This array's original purpose was to be the source for `scoredTimeline` and for pagination.
            // With `topRecommendations` providing a direct list of IDs, `recommendedChronologicalPosts`
            // might become obsolete for the "For You" feed, or be repurposed (e.g., for a "Latest" fallback within "For You").
            // For now, it's not being populated directly in this new flow.
            // This also means `fetchMoreRecommended()` which paginates `recommendedChronologicalPosts`
            // will not work as expected for the new "For You" feed without significant changes.
            // Setting canLoadMoreRecommended based on the fixed fetch limit for now.
            if fetchedPosts.count < 50 { // Assuming limit was 50
                canLoadMoreRecommended = false
            } else {
                // If topRecommendations itself can be paginated, canLoadMoreRecommended would depend on that.
                // For now, a single fetch of 50 is assumed.
                canLoadMoreRecommended = false // Or true if topRecommendations has its own pagination beyond the initial fetch
            }
            
            initializeLoadingStates(for: posts)
            await fetchTopPostsForHeader()

        } catch {
            logger.error("Error loading recommended timeline: \(error.localizedDescription)")
            handleFetchError(error)
            posts = []
            recommendedForYouPosts = []
            // recommendedChronologicalPosts = []
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
            hasLoadedLatestOnce = true // Mark as loaded
            logger.info("Successfully loaded 'Latest' timeline for the first time.")
        } catch {
            handleFetchError(error)
            posts = []
            // Do not set hasLoadedLatestOnce = true on error, so it can retry on next selection.
        }
    }
    
    private func loadTrendingTimeline() async {
        do {
            posts = try await timelineService.fetchTrendingTimeline()
            nextPageInfo = nil // Trending usually not paginated with maxId like home timeline
            initializeLoadingStates(for: posts)
            topPosts = try await trendingService.fetchTrendingPosts() // Fetch specific top posts for trending header
            hasLoadedTrendingOnce = true // Mark as loaded
            logger.info("Successfully loaded 'Trending' timeline for the first time.")
        } catch {
            handleFetchError(error)
            posts = []
            topPosts = []
            // Do not set hasLoadedTrendingOnce = true on error.
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
    
    // In TimelineViewModel.swift, replace existing toggleLike method
    func toggleLike(for post: Post) { // 'post' here is the displayPost (original content)
        // Calculate the new state for optimistic update
        let newIsFavourited = !post.isFavourited
        let newFavouritesCount = post.favouritesCount + (newIsFavourited ? 1 : -1)

        // Create a temporary Post object representing the desired optimistic state
        let optimisticPost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                  account: post.account, mediaAttachments: post.mediaAttachments,
                                  isFavourited: newIsFavourited,
                                  isReblogged: post.isReblogged,
                                  reblogsCount: post.reblogsCount,
                                  favouritesCount: newFavouritesCount,
                                  repliesCount: post.repliesCount, mentions: post.mentions, tags: post.tags,
                                  card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                  reblog: nil, // This represents the original post's state, not a wrapper
                                  rebloggedBy: post.rebloggedBy)

        // Apply optimistic update to all relevant arrays
        updatePostInArray(&posts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&topPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedForYouPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedChronologicalPosts, with: optimisticPost, isOptimistic: true)

        updateLoadingState(for: post.id, isLoading: true) // Use displayPost ID for loading state

        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleLike(postID: post.id)
                if let updated = returnedPost {
                    // Update all arrays with the actual post returned from the API
                    updatePostInArray(&posts, with: updated, isOptimistic: false)
                    updatePostInArray(&topPosts, with: updated, isOptimistic: false)
                    updatePostInArray(&recommendedForYouPosts, with: updated, isOptimistic: false)
                    updatePostInArray(&recommendedChronologicalPosts, with: updated, isOptimistic: false)
                } else {
                    // If API returns nil, assume optimistic update was correct (success without new object)
                    // Or, if this means no change, then revert. Need to clarify API contract.
                    // Assuming returnedPost == nil implies success but no new object, so optimistic update stands.
                }
                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: newIsFavourited ? .like : .unlike,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleLike: \(error.localizedDescription)")
                // Revert optimistic update on error by creating a post with original state
                let originalStatePost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                             account: post.account, mediaAttachments: post.mediaAttachments,
                                             isFavourited: post.isFavourited, // Original state
                                             isReblogged: post.isReblogged,
                                             reblogsCount: post.reblogsCount,
                                             favouritesCount: post.favouritesCount, // Original count
                                             repliesCount: post.repliesCount, mentions: post.mentions, tags: post.tags,
                                             card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                             reblog: nil, // Represents original post state
                                             rebloggedBy: post.rebloggedBy)
                updatePostInArray(&posts, with: originalStatePost, isOptimistic: false) // Revert state in all lists
                updatePostInArray(&topPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedForYouPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedChronologicalPosts, with: originalStatePost, isOptimistic: false)
                alertError = AppError(message: "Failed to like post", underlyingError: error)
            }
        }
    }
    
    // In TimelineViewModel.swift, replace existing toggleRepost method
    func toggleRepost(for post: Post) { // 'post' here is the displayPost (original content)
        let newIsReblogged = !post.isReblogged
        let newReblogsCount = post.reblogsCount + (newIsReblogged ? 1 : -1)

        let optimisticPost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                  account: post.account, mediaAttachments: post.mediaAttachments,
                                  isFavourited: post.isFavourited,
                                  isReblogged: newIsReblogged, // Toggled state
                                  reblogsCount: newReblogsCount, // Toggled count
                                  favouritesCount: post.favouritesCount,
                                  repliesCount: post.repliesCount, mentions: post.mentions, tags: post.tags,
                                  card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                  reblog: nil,
                                  rebloggedBy: post.rebloggedBy)

        updatePostInArray(&posts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&topPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedForYouPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedChronologicalPosts, with: optimisticPost, isOptimistic: true)

        updateLoadingState(for: post.id, isLoading: true)

        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleRepost(postID: post.id)
                if let updated = returnedPost {
                    updatePostInArray(&posts, with: updated, isOptimistic: false)
                    updatePostInArray(&topPosts, with: updated, isOptimistic: false)
                    updatePostInArray(&recommendedForYouPosts, with: updated, isOptimistic: false)
                    updatePostInArray(&recommendedChronologicalPosts, with: updated, isOptimistic: false)
                }
                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: newIsReblogged ? .repost : .unrepost,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleRepost: \(error.localizedDescription)")
                let originalStatePost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                             account: post.account, mediaAttachments: post.mediaAttachments,
                                             isFavourited: post.isFavourited,
                                             isReblogged: post.isReblogged, // Original state
                                             reblogsCount: post.reblogsCount, // Original count
                                             favouritesCount: post.favouritesCount,
                                             repliesCount: post.repliesCount, mentions: post.mentions, tags: post.tags,
                                             card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                             reblog: nil,
                                             rebloggedBy: post.rebloggedBy)
                updatePostInArray(&posts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&topPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedForYouPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedChronologicalPosts, with: originalStatePost, isOptimistic: false)
                alertError = AppError(message: "Failed to repost", underlyingError: error)
            }
        }
    }
    
    // In TimelineViewModel.swift, replace existing comment method
    func comment(on post: Post, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Optimistic update for repliesCount
        let newRepliesCount = post.repliesCount + 1

        let optimisticPost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                  account: post.account, mediaAttachments: post.mediaAttachments,
                                  isFavourited: post.isFavourited,
                                  isReblogged: post.isReblogged,
                                  reblogsCount: post.reblogsCount,
                                  favouritesCount: post.favouritesCount,
                                  repliesCount: newRepliesCount, // Incremented count
                                  mentions: post.mentions, tags: post.tags,
                                  card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                  reblog: nil,
                                  rebloggedBy: post.rebloggedBy)

        updatePostInArray(&posts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&topPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedForYouPosts, with: optimisticPost, isOptimistic: true)
        updatePostInArray(&recommendedChronologicalPosts, with: optimisticPost, isOptimistic: true)

        updateLoadingState(for: post.id, isLoading: true)
        Task {
            defer { updateLoadingState(for: post.id, isLoading: false) }
            do {
                _ = try await postActionService.comment(postID: post.id, content: content)
                // The comment API might not return the updated Post with repliesCount.
                // Assuming it just returns the new comment post. So, rely on optimistic update.
                // If API *does* return updated parent post, fetch context again or update with that.

                commentText = "" // Expected to be a @Published property
                showingCommentSheet = false // Expected to be a @Published property
                selectedPostForComments = nil // Expected to be a @Published property

                RecommendationService.shared.logInteraction(
                    statusID: post.id,
                    actionType: .comment,
                    accountID: currentUserAccountID,
                    authorAccountID: post.account?.id,
                    postURL: post.url,
                    tags: post.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed to post comment: \(error.localizedDescription)")
                // Revert optimistic update on error for repliesCount
                let originalStatePost = Post(id: post.id, content: post.content, createdAt: post.createdAt,
                                             account: post.account, mediaAttachments: post.mediaAttachments,
                                             isFavourited: post.isFavourited,
                                             isReblogged: post.isReblogged,
                                             reblogsCount: post.reblogsCount,
                                             favouritesCount: post.favouritesCount,
                                             repliesCount: post.repliesCount, // Original count
                                             mentions: post.mentions, tags: post.tags,
                                             card: post.card, url: post.url, inReplyTo: post.inReplyTo,
                                             reblog: nil,
                                             rebloggedBy: post.rebloggedBy)
                updatePostInArray(&posts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&topPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedForYouPosts, with: originalStatePost, isOptimistic: false)
                updatePostInArray(&recommendedChronologicalPosts, with: originalStatePost, isOptimistic: false)
                alertError = AppError(message: "Failed to post comment", underlyingError: error)
            }
        }
    }
    
    func showComments(for post: Post) {
        selectedPostForComments = post
        showingCommentSheet = true
    }

    public func logNotInterested(for post: Post) {
        // The 'post' parameter here is the one displayed, which could be a reblog or an original post.
        // We want to log the interaction for the *content* of the post.
        let targetPost = post.reblog ?? post

        logger.info("Logging 'Not Interested' for post ID: \(targetPost.id)")

        self.recommendationService.logInteraction(
            statusID: targetPost.id,
            actionType: .dislikePost,
            accountID: currentUserAccountID, // ID of the user performing the action
            authorAccountID: targetPost.account?.id, // ID of the post's author
            postURL: targetPost.url,
            tags: targetPost.tags?.compactMap { $0.name }
        )

        // Optimistic UI Removal for "Not Interested"
        // The `targetPost` is the actual content post (original or reblog's content).
        // We need to find the item in the list that either is this targetPost or reblogs it.

        // Remove from recommendedForYouPosts first.
        // This is the source array for the "For You" feed.
        if let indexInRecForYou = recommendedForYouPosts.firstIndex(where: { $0.id == targetPost.id || ($0.reblog?.id == targetPost.id) }) {
            recommendedForYouPosts.remove(at: indexInRecForYou)
            logger.info("Optimistically removed post (content ID: \(targetPost.id)) from recommendedForYouPosts.")
        }

        // If the current filter is .recommended, then 'posts' is a direct reflection of 'recommendedForYouPosts'
        // and should also be updated.
        if selectedFilter == .recommended {
            if let indexInPosts = posts.firstIndex(where: { $0.id == targetPost.id || ($0.reblog?.id == targetPost.id) }) {
                posts.remove(at: indexInPosts)
                logger.info("Optimistically removed post (content ID: \(targetPost.id)) from main posts list (recommended filter active).")
            }
        }

        // Note: Removing from `recommendedChronologicalPosts` is not done here as its role
        // in the "For You" feed has changed with the new recommendation flow.
        // Also, not removing from `topPosts` as "Not Interested" is typically for main feed items.
    }
    
    // MARK: - Loading State Management
    
    private func initializeLoadingStates(for newPosts: [Post]) {
        // No changes needed here, already uses post.id
        var newStates = postLoadingStates
        for post in newPosts where newStates[post.id] == nil {
            newStates[post.id] = false
        }
        postLoadingStates = newStates
    }
    
    // CORRECTED METHOD:
    func isLoading(forPostId postId: String) -> Bool {
        postLoadingStates[postId] ?? false
    }
    
    private func updateLoadingState(for postId: String, isLoading: Bool) {
        // No changes needed here, already uses String postId
        postLoadingStates[postId] = isLoading
    }
    
    // MARK: - Helper to update posts in all lists
    
    private func updatePostInArray(_ array: inout [Post], with updatedPost: Post, isOptimistic: Bool) {
        for i in 0..<array.count {
            // Case 1: The current element in the array is the updated post itself (original post)
            if array[i].id == updatedPost.id {
                array[i].isFavourited = updatedPost.isFavourited
                array[i].isReblogged = updatedPost.isReblogged
                array[i].favouritesCount = updatedPost.favouritesCount
                array[i].reblogsCount = updatedPost.reblogsCount
                // Replies count update should be careful, only for comment actions or if returned API post has updated count
                if isOptimistic || array[i].repliesCount != updatedPost.repliesCount {
                     array[i].repliesCount = updatedPost.repliesCount
                }
                // Important: Reassign the element to trigger SwiftUI ForEach updates for class elements
                array[i] = array[i]
                return // Found and updated, exit
            }
            // Case 2: The current element is a reblog wrapper of the updated post
            else if let rebloggedContent = array[i].reblog, rebloggedContent.id == updatedPost.id {
                rebloggedContent.isFavourited = updatedPost.isFavourited
                rebloggedContent.isReblogged = updatedPost.isReblogged
                rebloggedContent.favouritesCount = updatedPost.favouritesCount
                rebloggedContent.reblogsCount = updatedPost.reblogsCount
                if isOptimistic || rebloggedContent.repliesCount != updatedPost.repliesCount {
                     rebloggedContent.repliesCount = updatedPost.repliesCount
                }
                // Important: Reassign the reblog property and then the wrapper itself
                array[i].reblog = rebloggedContent
                array[i] = array[i]
                return // Found and updated, exit
            }
        }
    }

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

// MARK: - Context Fetching Extension

extension TimelineViewModel {
    func fetchContext(for post: Post) async -> PostContext? {
        logger.debug("Fetching context for post ID: \(post.id)")
        do {
            // timelineService.fetchPostContext(postId:) is already defined
            // and calls mastodonAPIService.fetchPostContext(postId:)
            let context = try await timelineService.fetchPostContext(postId: post.id)
            logger.debug("Successfully fetched context for post ID: \(post.id). Ancestors: \(context.ancestors.count), Descendants (replies): \(context.descendants.count)")
            return context
        } catch {
            logger.error("Failed to fetch context for post ID \(post.id): \(error.localizedDescription)")
            // Optionally, you can set an error on the ViewModel to be displayed to the user
            // self.alertError = AppError(message: "Could not load replies for the post.", underlyingError: error)
            return nil // Return nil if fetching context fails
        }
    }
}
