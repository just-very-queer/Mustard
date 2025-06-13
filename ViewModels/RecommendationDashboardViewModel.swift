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
        Task {
            await recommendationService.configure(modelContext: getContext())
        }
    }

    private func getContext() -> ModelContext {
        // Assuming a shared model container or a way to access it.
        // This might need adjustment based on your app's architecture.
        // For now, let's assume a global context exists or can be created.
        // This is a placeholder and might need to be passed in or accessed differently.
        let schema = Schema([
            UserAffinity.self,
            HashtagAffinity.self,
            Interaction.self,
            Post.self,
            Account.self,
            MediaAttachment.self,
            ServerModel.self,
            InstanceModel.self,
            Config.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return ModelContext(container)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

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
            var userDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
            self.userAffinities = try context.fetch(userDescriptor)

            // Fetch HashtagAffinities
            var hashtagDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
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
