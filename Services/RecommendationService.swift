import Foundation
import SwiftData
import OSLog // For logging

@MainActor // To ensure it can safely interact with MainActor-isolated ViewModels and publish changes
class RecommendationService: ObservableObject {
    static let shared = RecommendationService()

    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendationService")

    private init() {
        // Access the shared model container from the app
        guard let container = MustardApp.sharedModelContainer else {
            // This should not happen if MustardApp initializes sharedModelContainer correctly
            fatalError("RecommendationService: MustardApp.sharedModelContainer is nil. Ensure it's initialized before accessing RecommendationService.shared.")
        }
        self.modelContext = ModelContext(container)
        self.modelContext.autosaveEnabled = true 
        
        logger.info("RecommendationService initialized with ModelContext.")
        // Perform initial setup or load existing data if needed
        // For example, you might want to trigger an initial affinity calculation
        // or load existing affinities if they are not automatically fetched by views.
        // Task {
        //    await calculateAffinities() // Example: Run calculation on init (consider if this is desired)
        // }
    }

    // Placeholder for interaction logging method
    func logInteraction(statusID: String? = nil, // Made optional as not all interactions are post-specific
                        actionType: InteractionType,
                        accountID: String? = nil, // User performing action (e.g., current authenticated user)
                        authorAccountID: String? = nil, // Post author
                        postURL: String? = nil,
                        tags: [String]? = nil, // Hashtags from the post
                        viewDuration: Double? = nil, // For timeSpent action
                        linkURL: String? = nil) { // For linkOpen action
        
        let newInteraction = Interaction(
            statusID: statusID,
            actionType: actionType,
            timestamp: Date(), // Current time
            accountID: accountID,
            authorAccountID: authorAccountID,
            postURL: postURL,
            tags: tags,
            viewDuration: viewDuration,
            linkURL: linkURL
        )

        modelContext.insert(newInteraction)
        // Autosave is enabled via self.modelContext.autosaveEnabled = true in init()
        logger.info("Logged interaction: \(actionType.rawValue, privacy: .public) for status \(statusID ?? "N/A", privacy: .public). User: \(accountID ?? "N/A"). Author: \(authorAccountID ?? "N/A")")
    }
    
    // Placeholder for affinity calculation method
    // Inside RecommendationService - calculateAffinities method
    @MainActor // Ensure modelContext operations are on main thread
    func calculateAffinities() async {
        logger.info("Starting affinity calculation...")
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        // Fetch recent interactions
        var interactionDescriptor = FetchDescriptor<Interaction>(
            predicate: #Predicate { $0.timestamp >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        // For testing, you might want to fetch all interactions if recent ones are few:
        // interactionDescriptor.predicate = nil 
        
        guard let interactions = try? modelContext.fetch(interactionDescriptor) else {
            logger.error("Failed to fetch interactions.")
            return
        }

        if interactions.isEmpty {
            logger.info("No recent interactions to process for affinity calculation.")
            return
        }

        let weights: [InteractionType: Double] = [
            .like: 1.0, .comment: 3.0, .repost: 2.0, .linkOpen: 1.5, .view: 0.2,
            .unlike: -0.5, .unrepost: -0.5 // Optional: negative weights for "undo" actions
        ]

        // --- Author Affinity Calculation ---
        var authorScores: [String: Double] = [:]
        var authorInteractionCounts: [String: Int] = [:]

        for interaction in interactions {
            guard let authorId = interaction.authorAccountID else { continue }
            let scoreBoost = weights[interaction.actionType] ?? 0.0
            authorScores[authorId, default: 0.0] += scoreBoost
            authorInteractionCounts[authorId, default: 0] += 1
        }

        for (authorId, calculatedScore) in authorScores {
            let count = authorInteractionCounts[authorId] ?? 0
            updateUserAffinity(authorAccountID: authorId, score: calculatedScore, interactionCount: count)
        }
        logger.info("Author affinities updated.")

        // --- Hashtag Affinity Calculation ---
        var tagScores: [String: Double] = [:]
        var tagInteractionCounts: [String: Int] = [:]

        for interaction in interactions {
            guard let tags = interaction.tags, !tags.isEmpty else { continue }
            let scoreBoost = weights[interaction.actionType] ?? 0.0
            for tagName in tags {
                tagScores[tagName, default: 0.0] += scoreBoost
                tagInteractionCounts[tagName, default: 0] += 1
            }
        }

        for (tagName, calculatedScore) in tagScores {
            let count = tagInteractionCounts[tagName] ?? 0
            updateHashtagAffinity(tag: tagName, score: calculatedScore, interactionCount: count)
        }
        logger.info("Hashtag affinities updated.")
        logger.info("Affinity calculation completed.")
    }

    // Helper to update/create UserAffinity
    @MainActor
    private func updateUserAffinity(authorAccountID: String, score: Double, interactionCount: Int) {
        let fetchDescriptor = FetchDescriptor<UserAffinity>(predicate: #Predicate { $0.authorAccountID == authorAccountID })
        do {
            if let existingAffinity = try modelContext.fetch(fetchDescriptor).first {
                existingAffinity.score = score // Or += score for cumulative
                existingAffinity.interactionCount = interactionCount // Or += for cumulative
                existingAffinity.lastUpdated = Date()
            } else {
                let newAffinity = UserAffinity(authorAccountID: authorAccountID, score: score, lastUpdated: Date(), interactionCount: interactionCount)
                modelContext.insert(newAffinity)
            }
        } catch {
            logger.error("Error updating UserAffinity for \(authorAccountID): \(error.localizedDescription)")
        }
    }

    // Helper to update/create HashtagAffinity
    @MainActor
    private func updateHashtagAffinity(tag: String, score: Double, interactionCount: Int) {
        let fetchDescriptor = FetchDescriptor<HashtagAffinity>(predicate: #Predicate { $0.tag == tag })
        do {
            if let existingAffinity = try modelContext.fetch(fetchDescriptor).first {
                existingAffinity.score = score
                existingAffinity.interactionCount = interactionCount
                existingAffinity.lastUpdated = Date()
            } else {
                let newAffinity = HashtagAffinity(tag: tag, score: score, lastUpdated: Date(), interactionCount: interactionCount)
                modelContext.insert(newAffinity)
            }
        } catch {
            logger.error("Error updating HashtagAffinity for \(tag): \(error.localizedDescription)")
        }
    }

    // Example of a method to fetch some data (not required by subtask, just for illustration)
    // func fetchTopUserAffinities(limit: Int = 5) -> [UserAffinity] {
    //     do {
    //         var fetchDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
    //         fetchDescriptor.fetchLimit = limit
    //         return try modelContext.fetch(fetchDescriptor)
    //     } catch {
    //         logger.error("Error fetching top user affinities: \(error.localizedDescription, privacy: .public)")
    //         return []
    //     }
    // }

    // MARK: - Recommendation API Methods

    @MainActor
    func topRecommendations(limit: Int) async -> [String] { // Returns Post IDs
        logger.info("Fetching top recommendations (limit: \(limit))...")
        var recommendedPostIDs: Set<String> = [] // Use Set to avoid duplicates initially

        // 1. Fetch top UserAffinities
        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        userAffinityDescriptor.fetchLimit = limit // Consider fetching more to have a larger pool
        let topUserAffinities = (try? modelContext.fetch(userAffinityDescriptor)) ?? []

        // 2. Fetch top HashtagAffinities
        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        hashtagAffinityDescriptor.fetchLimit = limit // Consider fetching more
        let topHashtagAffinities = (try? modelContext.fetch(hashtagAffinityDescriptor)) ?? []

        // 3. For simplicity, fetch recent posts and then filter/score them
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let postDescriptor = FetchDescriptor<Post>( // Ensure Post model is imported/accessible
            predicate: #Predicate { $0.createdAt >= sevenDaysAgo }, // Recent posts
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recentPosts = (try? modelContext.fetch(postDescriptor)) ?? []

        if recentPosts.isEmpty {
            logger.info("No recent posts found to generate recommendations.")
            return []
        }
        
        // --- Simplified Scoring & Selection ---
        let userAffinityMap = Dictionary(uniqueKeysWithValues: topUserAffinities.map { ($0.authorAccountID, $0.score) })
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: topHashtagAffinities.map { ($0.tag, $0.score) })

        var scoredPosts: [(postID: String, score: Double)] = []

        for post in recentPosts {
            var postScore: Double = 0.0
            if let authorAffinity = userAffinityMap[post.account?.id ?? ""] { // account.id should be author's ID
                postScore += authorAffinity
            }
            // Assuming Post.tags is [Tag]? and Tag has a 'name' property
            post.tags?.forEach { tag in 
                if let tagName = tag.name, let hashtagAffinity = hashtagAffinityMap[tagName] {
                    postScore += hashtagAffinity
                }
            }
            // Add a small decay factor for older posts within the 7-day window
            let timeSinceCreation = Date().timeIntervalSince(post.createdAt)
            let decayFactor = max(0, 1.0 - (timeSinceCreation / (7.0 * 24.0 * 60.0 * 60.0))) // Ensure decayFactor is not negative
            postScore *= decayFactor


            if postScore > 0.1 { // Only consider posts with some positive affinity score
                 scoredPosts.append((post.id, postScore))
            }
        }
        
        // Sort by score and take top N
        scoredPosts.sort { $0.score > $1.score }
        recommendedPostIDs = Set(scoredPosts.prefix(limit).map { $0.postID })
        
        // TODO: Filter out posts already interacted with by the current user.
        // This requires fetching user's interactions and comparing post.id.

        logger.info("Found \(recommendedPostIDs.count) top recommended post IDs.")
        return Array(recommendedPostIDs)
    }

    @MainActor
    func scoredTimeline(_ timeline: [Post]) async -> [Post] {
        logger.info("Scoring timeline with \(timeline.count) posts...")
        if timeline.isEmpty { return [] }

        // 1. Fetch affinities (could be cached or passed if recently fetched)
        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let userAffinities = (try? modelContext.fetch(userAffinityDescriptor)) ?? []
        let userAffinityMap = Dictionary(uniqueKeysWithValues: userAffinities.map { ($0.authorAccountID, $0.score) })

        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let hashtagAffinities = (try? modelContext.fetch(hashtagAffinityDescriptor)) ?? []
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: hashtagAffinities.map { ($0.tag, $0.score) })
        
        // 2. Score each post in the timeline
        let scoredPostsTuples = timeline.map { post -> (post: Post, score: Double) in
            var postScore: Double = 0.0
            if let authorId = post.account?.id, let affinityScore = userAffinityMap[authorId] {
                postScore += affinityScore
            }
            // Assuming Post.tags is [Tag]? and Tag has a 'name' property
            post.tags?.forEach { tag in 
                if let tagName = tag.name, let affinityScore = hashtagAffinityMap[tagName] {
                    postScore += affinityScore
                }
            }
            // Optional: Add a slight bonus for newer posts if timeline is not already sorted by recency
            // postScore += (post.createdAt.timeIntervalSinceNow / (60*60*24)) * 0.01 
            return (post, postScore)
        }

        // 3. Sort the timeline by the calculated score
        let reorderedTimeline = scoredPostsTuples.sorted { $0.score > $1.score }.map { $0.post }
        
        logger.info("Timeline scoring complete.")
        return reorderedTimeline
    }
}
