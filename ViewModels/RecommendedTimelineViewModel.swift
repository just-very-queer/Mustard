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
    // Optional: Store current user ID if needed for recommendations or context
    // private let currentUserAccountID: String?

    // MARK: - State for Pagination
    private var homeTimelineMaxID: String? = nil
    private var canLoadMoreHomeTimeline: Bool = true
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendedTimelineViewModel")

    // MARK: - Initializer
    init(timelineService: TimelineServiceProtocol,
         recommendationService: RecommendationService = .shared /*, currentUserAccountID: String? = nil */) {
        self.timelineService = timelineService
        self.recommendationService = recommendationService
        // self.currentUserAccountID = currentUserAccountID
        logger.info("RecommendedTimelineViewModel initialized.")
    }

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
}

// Enum to differentiate sections if needed for pagination or UI logic
enum RecommendedTimelineSection {
    case forYou
    case chronological
}
