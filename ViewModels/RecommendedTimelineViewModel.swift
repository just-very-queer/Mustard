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
    func loadMoreContentIfNeeded(currentItem item: Post?, section: RecommendedTimelineSection) async {
        // Implementation in Subtask 5.5
        logger.debug("Load more content called for section \(section), item \(item?.id ?? "nil") (Placeholder)")
    }

    // Placeholder for pull-to-refresh (will be part of Subtask 5.5)
    func refreshTimeline() async {
        // Implementation in Subtask 5.5
        logger.info("Refresh timeline called (Placeholder)")
        await initialLoad() // Simplest refresh is to call initialLoad
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
