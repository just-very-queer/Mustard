import Foundation
import Combine
import SwiftData // If directly using Post, etc.
import SwiftUI // For @Published
import OSLog // For logging

@MainActor
class RecommendedTimelineViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var forYouPosts: [Post] = []
    @Published private(set) var chronologicalPosts: [Post] = [] // Fallback, original order
    @Published private(set) var isLoading: Bool = false
    @Published var alertError: AppError? = nil // For error alerts

    // MARK: - Services
    private let timelineService: TimelineServiceProtocol
    private let recommendationService: RecommendationService
    private let postActionService: PostActionServiceProtocol // Added for PostView actions
    // Optional: Store current user ID if needed for recommendations or context
    var currentUserAccountID: String? = "USER_ID_PLACEHOLDER_RECO_VM" // TODO: Replace

    // MARK: - State for Pagination
    private var homeTimelineMaxID: String? = nil
    private var canLoadMoreHomeTimeline: Bool = true
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendedTimelineViewModel")

    // MARK: - Initializer
    init(timelineService: TimelineServiceProtocol,
         recommendationService: RecommendationService = .shared,
         postActionService: PostActionServiceProtocol /*, currentUserAccountID: String? = nil */) {
        self.timelineService = timelineService
        self.recommendationService = recommendationService
        self.postActionService = postActionService // Store it
        // self.currentUserAccountID = currentUserAccountID
        logger.info("RecommendedTimelineViewModel initialized.")
    }

    // MARK: - Published Properties for PostView actions (if needed, or handled via methods)
    @Published var selectedPostForComments: Post?
    @Published var showingCommentSheet = false
    @Published var commentText: String = ""
    // Minimal loading states for individual posts if PostView expects this from its VM
    // For simplicity, we might not replicate all of TimelineViewModel's published states here
    // and PostView might need to be adapted to a simpler action protocol.
    @Published private(set) var postLoadingStates: [String: Bool] = [:]


    // MARK: - Public Methods
    func initialLoad() async {
        guard !isLoading else {
            logger.debug("Already loading, initialLoad call skipped.")
            return
        }
        logger.info("Starting initial load...")
        isLoading = true
        alertError = nil
        
        // Reset pagination for home timeline
        homeTimelineMaxID = nil
        canLoadMoreHomeTimeline = true
        
        do {
            // Fetch initial batch of home timeline
            // Using limit: 40 as suggested for better initial scoring base
            let initialChronologicalPosts = try await timelineService.WorkspaceHomeTimeline(maxId: homeTimelineMaxID, minId: nil, limit: 40)
            logger.info("Fetched \(initialChronologicalPosts.count) chronological posts.")
            
            self.chronologicalPosts = initialChronologicalPosts
            if initialChronologicalPosts.count < 40 { // Check against the limit used
                canLoadMoreHomeTimeline = false
                logger.info("Can no longer load more chronological posts.")
            } else {
                homeTimelineMaxID = initialChronologicalPosts.last?.id
            }

            // Score and sort for the "For You" section
            if initialChronologicalPosts.isEmpty {
                logger.info("Chronological posts list is empty, For You posts will also be empty.")
                self.forYouPosts = []
            } else {
                self.forYouPosts = await recommendationService.scoredTimeline(initialChronologicalPosts)
                logger.info("Scored timeline, \(self.forYouPosts.count) posts in For You section.")
            }
            
        } catch let error as AppError {
            handleError(error, context: "Initial load for recommended timeline")
        } catch {
            let appError = AppError.custom(message: "An unexpected error occurred during initial load.", underlyingError: error)
            handleError(appError, context: "Initial load for recommended timeline")
        }
        isLoading = false
        logger.info("Initial load finished. isLoading: \(self.isLoading)")
    }
    
    // Placeholder for loadMore (will be part of Subtask 5.5)
    @MainActor
    func loadMoreContentIfNeeded(currentItem item: Post?, section: RecommendedTimelineSection) async {
        // For now, we only paginate the chronological section,
        // and the "For You" section is a re-score of all loaded chronological posts.
        guard section == .chronological else {
            logger.debug("Pagination attempted for non-chronological section, skipping.")
            return
        }

        guard !isLoading else {
            logger.debug("Already loading, skipping pagination call.")
            return
        }

        guard canLoadMoreHomeTimeline else {
            logger.debug("Cannot load more chronological posts, end reached or limit too low.")
            return
        }

        // Determine if we are near the end of the current list
        let threshold = 5 // Load when 5 items from end are visible
        var shouldLoad = false
        if let item = item, !chronologicalPosts.isEmpty {
            if let itemIndex = chronologicalPosts.firstIndex(where: { $0.id == item.id }) {
                if chronologicalPosts.count - itemIndex <= threshold {
                    shouldLoad = true
                }
            }
        } else if item == nil && chronologicalPosts.isEmpty { // For initial empty list but can still load.
             shouldLoad = true
        }


        guard shouldLoad else {
            // logger.debug("Not near end of list or item is nil when list not empty, skipping pagination.")
            return
        }

        logger.info("Loading more chronological posts (current maxID: \(self.homeTimelineMaxID ?? "nil"))...")
        isLoading = true
        alertError = nil

        do {
            let olderPosts = try await timelineService.WorkspaceHomeTimeline(
                maxId: self.homeTimelineMaxID,
                minId: nil,
                limit: 20 // Standard limit
            )

            if !olderPosts.isEmpty {
                self.chronologicalPosts.append(contentsOf: olderPosts)
                self.homeTimelineMaxID = olderPosts.last?.id
                logger.info("Loaded \(olderPosts.count) more posts. New maxID: \(self.homeTimelineMaxID ?? "nil")")

                if olderPosts.count < 20 { // Assuming 20 was the limit
                    canLoadMoreHomeTimeline = false
                    logger.info("End of chronological timeline reached.")
                }
                
                // Re-score the entire chronological list to update "For You"
                // This could be optimized if performance becomes an issue
                self.forYouPosts = await recommendationService.scoredTimeline(self.chronologicalPosts)
                logger.info("For You posts re-scored after pagination.")

            } else {
                canLoadMoreHomeTimeline = false
                logger.info("No older posts returned, end of chronological timeline.")
            }
            
        } catch let error as AppError {
            // self.alertError = error // handleError will set it
            handleError(error, context: "Loading more chronological posts")
        } catch {
            let appError = AppError.custom(message: "An unexpected error occurred while loading more posts.", underlyingError: error)
            // self.alertError = appError // handleError will set it
            handleError(appError, context: "Loading more chronological posts")
        }
        isLoading = false
    }

    // Placeholder for pull-to-refresh (will be part of Subtask 5.5)
    @MainActor
    func refreshTimeline() async {
        logger.info("Refreshing timeline...")
        isLoading = true // Indicate general loading for refresh
        // initialLoad already handles errors and sets isLoading to false at the end.
        await initialLoad()
        // Explicitly set isLoading to false here if initialLoad's final isLoading=false
        // isn't guaranteed to cover the refresh scenario adequately, though it should.
        isLoading = false
        logger.info("Timeline refresh completed.")
    }
    
    // Error Handling (similar to other ViewModels)
    private func handleError(_ error: Error, context: String) {
        logger.error("Error in RecommendedTimelineViewModel - \(context): \(error.localizedDescription, privacy: .public)")
        // Only set alertError if not already set by a more specific catch, or if the new error is different
        if self.alertError == nil || (self.alertError as? AppError)?.message != (error as? AppError)?.message {
             if let appErr = error as? AppError {
                 self.alertError = appErr
             } else {
                 self.alertError = AppError.custom(message: "Error in \(context): \(error.localizedDescription)", underlyingError: error)
             }
        }
    }

    // MARK: - Methods for PostView Actions
    // These methods will be called by PostView. They mirror some functionality of TimelineViewModel.
    
    func toggleLike(for post: Post) async {
        // Find which list the post is in and update it
        var postToUpdate: Post?
        var listToUpdate: PostListType?

        if let index = forYouPosts.firstIndex(where: { $0.id == post.id }) {
            postToUpdate = forYouPosts[index]
            listToUpdate = .forYou
        } else if let index = chronologicalPosts.firstIndex(where: { $0.id == post.id }) {
            postToUpdate = chronologicalPosts[index]
            listToUpdate = .chronological
        }

        guard var P = postToUpdate else { return }
        let originalIsFavourited = P.isFavourited
        let originalFavouritesCount = P.favouritesCount

        // Optimistic update
        P.isFavourited.toggle()
        P.favouritesCount += P.isFavourited ? 1 : -1
        updatePostInLists(P, listTypeHint: listToUpdate)
        
        updatePostLoadingState(for: post.id, isLoading: true)
        Task {
            defer { updatePostLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleLike(postID: P.id, isCurrentlyFavourited: originalIsFavourited)
                if let updatedPost = returnedPost {
                    updatePostInLists(updatedPost, listTypeHint: listToUpdate)
                }
                 RecommendationService.shared.logInteraction(
                    statusID: P.id, actionType: P.isFavourited ? .like : .unlike,
                    accountID: currentUserAccountID, authorAccountID: P.account?.id,
                    postURL: P.url, tags: P.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleLike: \(error.localizedDescription)")
                // Revert optimistic update
                P.isFavourited = originalIsFavourited
                P.favouritesCount = originalFavouritesCount
                updatePostInLists(P, listTypeHint: listToUpdate)
                handleError(error, context: "Toggling like for post \(P.id)")
            }
        }
    }

    func toggleRepost(for post: Post) async {
        var postToUpdate: Post?
        var listToUpdate: PostListType?

        if let index = forYouPosts.firstIndex(where: { $0.id == post.id }) {
            postToUpdate = forYouPosts[index]
            listToUpdate = .forYou
        } else if let index = chronologicalPosts.firstIndex(where: { $0.id == post.id }) {
            postToUpdate = chronologicalPosts[index]
            listToUpdate = .chronological
        }
        
        guard var P = postToUpdate else { return }
        let originalIsReblogged = P.isReblogged
        let originalReblogsCount = P.reblogsCount

        P.isReblogged.toggle()
        P.reblogsCount += P.isReblogged ? 1 : -1
        updatePostInLists(P, listTypeHint: listToUpdate)

        updatePostLoadingState(for: post.id, isLoading: true)
        Task {
            defer { updatePostLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await postActionService.toggleRepost(postID: P.id, isCurrentlyReblogged: originalIsReblogged)
                if let updatedPost = returnedPost {
                    updatePostInLists(updatedPost, listTypeHint: listToUpdate)
                }
                RecommendationService.shared.logInteraction(
                    statusID: P.id, actionType: P.isReblogged ? .repost : .unrepost,
                    accountID: currentUserAccountID, authorAccountID: P.account?.id,
                    postURL: P.url, tags: P.tags?.compactMap { $0.name }
                )
            } catch {
                logger.error("Failed toggleRepost: \(error.localizedDescription)")
                P.isReblogged = originalIsReblogged
                P.reblogsCount = originalReblogsCount
                updatePostInLists(P, listTypeHint: listToUpdate)
                handleError(error, context: "Toggling repost for post \(P.id)")
            }
        }
    }

    func comment(on post: Post, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updatePostLoadingState(for: post.id, isLoading: true)
        Task {
            defer { updatePostLoadingState(for: post.id, isLoading: false) }
            do {
                _ = try await postActionService.comment(postID: post.id, content: content)
                
                var P = post
                P.repliesCount += 1 // Optimistic update
                updatePostInLists(P) // Update both lists as comment count changes

                self.commentText = ""
                self.showingCommentSheet = false
                // self.selectedPostForComments = nil // This state is managed by the View if it shows the sheet
                logger.info("Commented on post \(post.id)")
                RecommendationService.shared.logInteraction(
                     statusID: post.id, actionType: .comment,
                     accountID: currentUserAccountID, authorAccountID: post.account?.id,
                     postURL: post.url, tags: post.tags?.compactMap { $0.name }
                 )
            } catch {
                logger.error("Failed to comment: \(error.localizedDescription)")
                handleError(error, context: "Commenting on post \(post.id)")
            }
        }
    }
    
    func showComments(for post: Post) async {
        selectedPostForComments = post
        showingCommentSheet = true // This will be observed by the View to present a sheet
    }
    
    // Helper to update posts in both lists to maintain consistency
    private func updatePostInLists(_ post: Post, listTypeHint: PostListType? = nil) {
        if listTypeHint == .forYou || listTypeHint == nil {
            if let index = forYouPosts.firstIndex(where: { $0.id == post.id }) {
                forYouPosts[index] = post
            }
        }
        if listTypeHint == .chronological || listTypeHint == nil {
            if let index = chronologicalPosts.firstIndex(where: { $0.id == post.id }) {
                chronologicalPosts[index] = post
            }
        }
    }
    
    private enum PostListType { case forYou, chronological }

    // Loading state for individual posts
    func isLoading(for post: Post) -> Bool {
        return postLoadingStates[post.id] ?? false
    }

    private func updatePostLoadingState(for postId: String, isLoading: Bool) {
        postLoadingStates[postId] = isLoading
    }
    
    // Minimal navigation path for profile, if needed directly from PostView actions
    @Published var navigationPath = NavigationPath()

    func navigateToProfile(_ user: User) async {
        navigationPath.append(user)
    }
}

// Enum to differentiate sections if needed for pagination or UI logic
enum RecommendedTimelineSection {
    case forYou
    case chronological
}
