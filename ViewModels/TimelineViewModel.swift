//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//  (REVISED: Stripped of data-fetching logic, now for UI state)
//

import Foundation
import Combine
import SwiftUI
import OSLog

@MainActor
final class TimelineViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedFilter: TimelineFilter = .recommended
    @Published var navigationPath = NavigationPath()
    
    // State for the comment sheet, which is a UI concern presented from the timeline.
    @Published var selectedPostForComments: Post?
    @Published var showingCommentSheet = false
    @Published var commentText: String = ""
    
    // Per-post loading states for actions initiated from the timeline UI.
    // This could also be moved to the view layer if preferred.
    @Published private(set) var postLoadingStates: [String: Bool] = [:]

    // Placeholder for current user account ID - this should be sourced from a proper auth service.
    internal var currentUserAccountID: String? = "USER_ID_PLACEHOLDER"
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineViewModel")

    init() {
        // The ViewModel no longer needs services passed to it, as data fetching
        // and post actions are handled elsewhere.
        logger.info("TimelineViewModel initialized for UI state management.")
    }
    
    // MARK: - UI-Related Actions
    
    func showComments(for post: Post) {
        selectedPostForComments = post
        showingCommentSheet = true
    }

    public func logNotInterested(for post: Post, recommendationService: RecommendationService) {
        // The 'post' parameter here is the one displayed.
        let targetPost = post.reblog ?? post

        logger.info("Logging 'Not Interested' for post ID: \(targetPost.id)")

        recommendationService.logInteraction(
            statusID: targetPost.id,
            actionType: .dislikePost,
            accountID: currentUserAccountID,
            authorAccountID: targetPost.account?.id,
            postURL: targetPost.url,
            tags: targetPost.tags?.compactMap { $0.name }
        )

        // The actual removal from the list will now be handled by the view,
        // which observes the data source (e.g., TimelineProvider).
        // This ViewModel's role is just to trigger the logging action.
    }
    
    // MARK: - Per-Post Loading State Management
    
    func isLoading(forPostId postId: String) -> Bool {
        postLoadingStates[postId] ?? false
    }
    
    func updateLoadingState(for postId: String, isLoading: Bool) {
        postLoadingStates[postId] = isLoading
    }
    
    // MARK: - Navigation
    
    func navigateToProfile(_ user: User) {
        navigationPath.append(user)
    }
    
    func navigateToDetail(for post: Post) {
        navigationPath.append(post)
    }
}
