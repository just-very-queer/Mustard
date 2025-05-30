//
//  RecommendationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import Foundation
import SwiftData
import OSLog // For logging

// Removed @MainActor from class declaration
class RecommendationService: ObservableObject {
    // Make shared a computed property or a function to ensure it's configured before use.
    // For simplicity here, we'll make it a regular instance and expect configuration.
    // A more robust approach might involve a `configureSharedInstance(modelContext:)` static func.
    static let shared = RecommendationService() // Keep as is for now, will configure context

    private var modelContext: ModelContext? // Optional, to be configured
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendationService")

    // Private init to enforce singleton pattern via `shared`
    private init() {
        logger.info("RecommendationService instance created. ModelContext needs configuration.")
    }
    
    // Method to configure the ModelContext, callable from both app targets
    func configure(modelContext: ModelContext) {
        if self.modelContext == nil { // Configure only once
            self.modelContext = modelContext
            self.modelContext?.autosaveEnabled = true
            logger.info("RecommendationService ModelContext configured.")
            
            // Perform initial setup or load existing data if needed
            Task {
                await calculateAffinities() // Call on init after context is set
            }
        } else {
            logger.info("RecommendationService ModelContext already configured.")
        }
    }
    
    // Guard for modelContext in methods that need it
    private func getContext() throws -> ModelContext {
        guard let context = modelContext else {
            let errorMsg = "RecommendationService ModelContext not configured."
            logger.critical("\(errorMsg, privacy: .public)")
            throw AppError(type: .other(errorMsg))
        }
        return context
    }

    // Helper struct to pass interaction data to background actor
    // Ensure InteractionType is Sendable (e.g., if it's an enum with raw values, it usually is)
    struct CapturedInteraction: Sendable {
        let statusID: String?
        let actionType: InteractionType
        let timestamp: Date
        let accountID: String?
        let authorAccountID: String?
        let postURL: String?
        let tags: [String]?
        let viewDuration: Double?
        let linkURL: String?
    }

    // This method can be called from any actor.
    func logInteraction(statusID: String? = nil, // Made optional as not all interactions are post-specific
                        actionType: InteractionType,
                        accountID: String? = nil, // User performing action (e.g., current authenticated user)
                        authorAccountID: String? = nil, // Post author
                        postURL: String? = nil,
                        tags: [String]? = nil, // Hashtags from the post
                        viewDuration: Double? = nil, // For timeSpent action
                        linkURL: String? = nil) { // For linkOpen action
        
        Task { // Fire-and-forget task to dispatch to background
            let interactionDetails = CapturedInteraction(
                statusID: statusID, actionType: actionType, timestamp: Date(),
                accountID: accountID, authorAccountID: authorAccountID, postURL: postURL,
                tags: tags, viewDuration: viewDuration, linkURL: linkURL
            )

            // Get ModelContainer. self.modelContext is set on MainActor during configure.
            // Accessing its .container property needs to be on MainActor.
            let mc = await MainActor.run { self.modelContext?.container }

            guard let modelContainer = mc else {
                 logger.error("Failed to log interaction: ModelContainer not available for background logging.")
                 return
            }

            await self.performBackgroundInteractionLogging(details: interactionDetails, modelContainer: modelContainer)
        }
    }

    @BackgroundActor
    private func performBackgroundInteractionLogging(details: CapturedInteraction, modelContainer: ModelContainer) async {
        let backgroundContext = ModelContext(modelContainer)
        // If precise save control is needed:
        // backgroundContext.autosaveEnabled = false

        let newInteraction = Interaction(
            statusID: details.statusID,
            actionType: details.actionType,
            timestamp: details.timestamp,
            accountID: details.accountID,
            authorAccountID: details.authorAccountID,
            postURL: details.postURL,
            tags: details.tags,
            viewDuration: details.viewDuration,
            linkURL: details.linkURL
        )

        backgroundContext.insert(newInteraction)

        // If not relying on main context's autosave or if backgroundContext.autosaveEnabled = false:
        // do {
        //     try backgroundContext.save()
        //     logger.info("Background: Interaction data saved successfully.")
        // } catch {
        //     logger.error("Background: Error saving interaction: \(error.localizedDescription)")
        // }

        logger.info("Background: Logged interaction: \(details.actionType.rawValue, privacy: .public) for status \(details.statusID ?? "N/A", privacy: .public)")
    }
    
    // Placeholder for affinity calculation method
    // Inside RecommendationService - calculateAffinities method
    @MainActor // Ensure modelContext operations are on main thread for triggering
    func calculateAffinities() async {
        logger.info("Starting affinity calculation (triggered on MainActor)...")
        
        guard let modelContainer = self.modelContext?.container else {
            logger.error("ModelContainer not available for background affinity calculation.")
            return
        }

        Task { // Launch a new unstructured task
            await self.performBackgroundAffinityCalculation(modelContainer: modelContainer)
        }
    }

    @BackgroundActor // Mark the new method to run on the background actor
    private func performBackgroundAffinityCalculation(modelContainer: ModelContainer) async {
        let backgroundContext = ModelContext(modelContainer)
        // Optional: Disable autosave for more control, then save manually at the end.
        // backgroundContext.autosaveEnabled = false

        logger.info("Performing background affinity calculation on BackgroundActor...")

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var interactionDescriptor = FetchDescriptor<Interaction>(
            predicate: #Predicate { $0.timestamp >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let interactions = try? backgroundContext.fetch(interactionDescriptor) else {
            logger.error("Background: Failed to fetch interactions.")
            return
        }

        if interactions.isEmpty {
            logger.info("Background: No recent interactions to process.")
            return
        }

        let weights: [InteractionType: Double] = [
            .like: 1.0, .comment: 3.0, .repost: 2.0, .linkOpen: 1.5, .view: 0.2,
            .unlike: -0.5, .unrepost: -0.5
        ]

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
            await self.updateUserAffinityOnBackground(authorAccountID: authorId, score: calculatedScore, interactionCount: count, context: backgroundContext)
        }
        logger.info("Background: Author affinities updated.")

        var tagScores: [String: Double] = [:]
        var tagInteractionCounts: [String: Int] = [:]
        for interaction in interactions {
            guard let tags = interaction.tags, !tags.isEmpty else { continue }
            let scoreBoost = weights[interaction.actionType] ?? 0.0
            for tagName in tags { // Assuming tags is [String]
                tagScores[tagName, default: 0.0] += scoreBoost
                tagInteractionCounts[tagName, default: 0] += 1
            }
        }

        for (tagName, calculatedScore) in tagScores {
            let count = tagInteractionCounts[tagName] ?? 0
            await self.updateHashtagAffinityOnBackground(tag: tagName, score: calculatedScore, interactionCount: count, context: backgroundContext)
        }
        logger.info("Background: Hashtag affinities updated.")

        // Explicitly save changes made in the background context if autosave is disabled
        // do {
        //    try backgroundContext.save()
        //    logger.info("Background: Affinity data saved successfully.")
        // } catch {
        //    logger.error("Background: Error saving affinity data: \(error.localizedDescription)")
        // }
        logger.info("Background affinity calculation finished.")
    }

    @BackgroundActor
    private func updateUserAffinityOnBackground(authorAccountID: String, score: Double, interactionCount: Int, context: ModelContext) async {
        let fetchDescriptor = FetchDescriptor<UserAffinity>(predicate: #Predicate { $0.authorAccountID == authorAccountID })
        do {
            if let existingAffinity = try context.fetch(fetchDescriptor).first {
                existingAffinity.score = score
                existingAffinity.interactionCount = interactionCount
                existingAffinity.lastUpdated = Date()
            } else {
                let newAffinity = UserAffinity(authorAccountID: authorAccountID, score: score, lastUpdated: Date(), interactionCount: interactionCount)
                context.insert(newAffinity)
            }
        } catch {
            logger.error("Background: Error updating UserAffinity for \(authorAccountID): \(error.localizedDescription)")
        }
    }

    @BackgroundActor
    private func updateHashtagAffinityOnBackground(tag: String, score: Double, interactionCount: Int, context: ModelContext) async {
        let fetchDescriptor = FetchDescriptor<HashtagAffinity>(predicate: #Predicate { $0.tag == tag })
        do {
            if let existingAffinity = try context.fetch(fetchDescriptor).first {
                existingAffinity.score = score
                existingAffinity.interactionCount = interactionCount
                existingAffinity.lastUpdated = Date()
            } else {
                let newAffinity = HashtagAffinity(tag: tag, score: score, lastUpdated: Date(), interactionCount: interactionCount)
                context.insert(newAffinity)
            }
        } catch {
            logger.error("Background: Error updating HashtagAffinity for \(tag): \(error.localizedDescription)")
        }
    }

    // MARK: - Recommendation API Methods

    @MainActor
    func topRecommendations(limit: Int) async -> [String] { // Returns Post IDs
        guard let currentContext = try? getContext() else { return [] }
        logger.info("Fetching top recommendations (limit: \(limit))...")
        var recommendedPostIDs: Set<String> = [] // Use Set to avoid duplicates initially

        // 1. Fetch top UserAffinities
        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        userAffinityDescriptor.fetchLimit = limit
        let topUserAffinities = (try? currentContext.fetch(userAffinityDescriptor)) ?? []

        // 2. Fetch top HashtagAffinities
        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        hashtagAffinityDescriptor.fetchLimit = limit
        let topHashtagAffinities = (try? currentContext.fetch(hashtagAffinityDescriptor)) ?? []

        // 3. For simplicity, fetch recent posts and then filter/score them
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let postDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.createdAt >= sevenDaysAgo }, // Recent posts
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recentPosts = (try? currentContext.fetch(postDescriptor)) ?? []

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
            if let authorAffinity = userAffinityMap[post.account?.id ?? ""] {
                postScore += authorAffinity
            }
            post.tags?.forEach { tag in
                if let hashtagAffinity = hashtagAffinityMap[tag.name] {
                    postScore += hashtagAffinity
                }
            }
            // Add a small decay factor for older posts within the 7-day window
            let timeSinceCreation = Date().timeIntervalSince(post.createdAt)
            let decayFactor = max(0, 1.0 - (timeSinceCreation / (7.0 * 24.0 * 60.0 * 60.0)))
            postScore *= decayFactor

            if postScore > 0.1 { // Only consider posts with some positive affinity score
                 scoredPosts.append((post.id, postScore))
            }
        }
        
        // Sort by score and take top N
        scoredPosts.sort { $0.score > $1.score }
        recommendedPostIDs = Set(scoredPosts.prefix(limit).map { $0.postID })
        
        logger.info("Found \(recommendedPostIDs.count) top recommended post IDs.")
        return Array(recommendedPostIDs)
    }

    @MainActor
    func scoredTimeline(_ timeline: [Post]) async -> [Post] {
        guard let currentContext = try? getContext() else { return timeline }
        logger.info("Scoring timeline with \(timeline.count) posts...")
        if timeline.isEmpty { return [] }

        // 1. Fetch affinities
        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let userAffinities = (try? currentContext.fetch(userAffinityDescriptor)) ?? []
        let userAffinityMap = Dictionary(uniqueKeysWithValues: userAffinities.map { ($0.authorAccountID, $0.score) })

        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let hashtagAffinities = (try? currentContext.fetch(hashtagAffinityDescriptor)) ?? []
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: hashtagAffinities.map { ($0.tag, $0.score) })
        
        // 2. Score each post in the timeline
        let scoredPostsTuples = timeline.map { post -> (post: Post, score: Double) in
            var postScore: Double = 0.0
            if let authorId = post.account?.id, let affinityScore = userAffinityMap[authorId] {
                postScore += affinityScore
            }
            post.tags?.forEach { tag in
                if let affinityScore = hashtagAffinityMap[tag.name] {
                    postScore += affinityScore
                }
            }
            return (post, postScore)
        }

        // 3. Sort the timeline by the calculated score
        let reorderedTimeline = scoredPostsTuples.sorted { $0.score > $1.score }.map { $0.post }
        
        logger.info("Timeline scoring complete.")
        return reorderedTimeline
    }

    @MainActor
    func getInterestScore(for postID: String, authorAccountID: String?, tags: [String]?) async -> Double {
        guard let currentContext = try? getContext() else { return 0.0 }
        var score: Double = 0.0

        // Fetch user affinity for the author
        if let authorAccountID = authorAccountID, !authorAccountID.isEmpty {
            let userAffinityDescriptor = FetchDescriptor<UserAffinity>(predicate: #Predicate { $0.authorAccountID == authorAccountID })
            do {
                if let userAffinity = try currentContext.fetch(userAffinityDescriptor).first {
                    score += userAffinity.score
                }
            } catch {
                logger.error("Error fetching user affinity for \(authorAccountID): \(error.localizedDescription)")
            }
        }

        // Fetch hashtag affinities for the tags
        if let postTags = tags, !postTags.isEmpty {
            var hashtagScore: Double = 0.0
            for tagName in postTags {
                let hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(predicate: #Predicate { $0.tag == tagName })
                do {
                    if let hashtagAffinity = try currentContext.fetch(hashtagAffinityDescriptor).first {
                        hashtagScore += hashtagAffinity.score
                    }
                } catch {
                    logger.error("Error fetching hashtag affinity for \(tagName): \(error.localizedDescription)")
                }
            }
            score += hashtagScore
        }
        
        return score
    }
}
