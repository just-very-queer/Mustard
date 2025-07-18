//
//  RecommendationDashboardViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  (REVISED & FIXED)

import SwiftUI
import Combine
import SwiftData

enum AffinityType {
    case user
    case hashtag
}

@MainActor
class RecommendationDashboardViewModel: ObservableObject {
    @Published var userAffinities: [UserAffinity] = []
    @Published var hashtagAffinities: [HashtagAffinity] = []

    internal let recommendationService: RecommendationService // Changed to internal

    init(recommendationService: RecommendationService = RecommendationService.shared) {
        self.recommendationService = recommendationService
        // Removed the Task that was incorrectly re-configuring the service.
    }

    // The getContext() method has been removed as it was creating an incorrect, isolated data store.
    // The view model now relies on the shared RecommendationService being configured at app launch.

    func fetchAffinities() async {
        // RecommendationService.calculateAffinities() should have populated and saved these.
        // We fetch them from the local SwiftData store.
        // Ensure RecommendationService's ModelContext is configured and used for saving affinities.

        guard let context = recommendationService.modelContext else {
            // Or handle this more gracefully, e.g., by logging an error
            print("Error: RecommendationService ModelContext not configured.")
            return
        }

        do {
            // Fetch UserAffinities
            let userDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
            self.userAffinities = try context.fetch(userDescriptor)

            // Fetch HashtagAffinities
            let hashtagDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
            self.hashtagAffinities = try context.fetch(hashtagDescriptor)

            print("Successfully fetched affinities. Users: \(self.userAffinities.count), Hashtags: \(self.hashtagAffinities.count)")

        } catch {
            print("Error fetching affinities: \(error.localizedDescription)")
            // Handle error appropriately
        }
    }

    func logManualAffinityAdjustment(type: AffinityType, id: String, boost: Double) {
        // This is a simplified representation.
        // The actual 'boost' might need to be translated into a score or a specific interaction
        // that the RecommendationService understands.
        // For now, we're logging a specific interaction type.
        // The `RecommendationService.calculateAffinities()` will later process these.

        let interactionType: InteractionType
        var authorAccountID: String? = nil
        var tags: [String]? = nil

        switch type {
        case .user:
            interactionType = .manualUserAffinity
            authorAccountID = id // Assuming 'id' is the authorAccountID for user affinity
        case .hashtag:
            interactionType = .manualHashtagAffinity
            tags = [id] // Assuming 'id' is the hashtag name
        }

        // We don't directly apply the boost here. We log an interaction that
        // `calculateAffinities` will use. The `weights` dictionary in RecommendationService
        // will determine how much this interaction affects the score.
        // If `boost` is meant to be the new score directly, that's a different logic
        // and would require a different method in RecommendationService.
        // For now, we use the predefined weights for manual affinity types.

        recommendationService.logInteraction(
            actionType: interactionType,
            authorAccountID: authorAccountID,
            tags: tags
        )

        print("Logged manual affinity adjustment for \(type) \(id) with implicit boost via \(interactionType).")

        // Optionally, re-calculate affinities immediately after logging a manual adjustment
        // Or, rely on a periodic recalculation. For immediate feedback:
        Task {
            await recommendationService.calculateAffinities() // Recalculate
            await fetchAffinities() // Refresh local data
        }
    }
}
