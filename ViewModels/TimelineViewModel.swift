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
