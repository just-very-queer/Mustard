//
//  RecommendationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import Foundation
import SwiftData
import OSLog // For logging

// FIX: Define the custom global actor
@globalActor
actor BackgroundActor {
    static let shared = BackgroundActor()
}

// Removed @MainActor from class declaration as methods are now explicitly annotated
class RecommendationService: ObservableObject {
    static let shared = RecommendationService()

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendationService")

    private init() {
        logger.info("RecommendationService instance created. ModelContext needs configuration.")
    }
    
    // This method is likely called from a @MainActor context (e.g., App init)
    func configure(modelContext: ModelContext) {
        if self.modelContext == nil {
            self.modelContext = modelContext
            // Ensure modelContext operations in configure are on the correct actor if needed
            // For example, accessing modelContext.container should be fine here if modelContext was passed from main actor.
            self.modelContext?.autosaveEnabled = true // This should be fine.
            logger.info("RecommendationService ModelContext configured.")
            
            Task { // This Task inherits the actor context of `configure`
                await calculateAffinities()
            }
        } else {
            logger.info("RecommendationService ModelContext already configured.")
        }
    }
    
    // This method might be called from various contexts, ensure it's actor-safe
    // or explicitly mark its actor context if it manipulates shared state
    // that isn't already protected (modelContext is actor-isolated by itself).
    private func getContext() throws -> ModelContext {
        guard let context = modelContext else {
            let errorMsg = "RecommendationService ModelContext not configured."
            logger.critical("\(errorMsg, privacy: .public)")
            throw AppError(type: .other(errorMsg))
        }
        return context
    }

    // logInteraction can be called from any actor, but ModelContext operations are safe.
    func logInteraction(statusID: String? = nil,
                        actionType: InteractionType,
                        accountID: String? = nil,
                        authorAccountID: String? = nil,
                        postURL: String? = nil,
                        tags: [String]? = nil,
                        viewDuration: Double? = nil,
                        linkURL: String? = nil) {
        
        // Operations on modelContext (like insert) are safe as ModelContext is Sendable
        // and handles its own thread safety.
        guard let context = try? getContext() else {
            logger.error("Failed to log interaction: ModelContext not available.")
            return
        }

        let newInteraction = Interaction(
            statusID: statusID,
            actionType: actionType,
            timestamp: Date(),
            accountID: accountID,
            authorAccountID: authorAccountID,
            postURL: postURL,
            tags: tags,
            viewDuration: viewDuration,
            linkURL: linkURL
        )

        context.insert(newInteraction)
        logger.info("Logged interaction: \(actionType.rawValue, privacy: .public) for status \(statusID ?? "N/A", privacy: .public). User: \(accountID ?? "N/A"). Author: \(authorAccountID ?? "N/A")")
    }
    
    // This method is explicitly @MainActor to safely access modelContext.container
    // and then dispatch work to the background.
    @MainActor
    func calculateAffinities() async {
        logger.info("Starting affinity calculation (triggered on MainActor)...")
        
        // Accessing self.modelContext and its container should be done on the MainActor
        // if RecommendationService itself isn't @MainActor globally.
        guard let modelContainer = self.modelContext?.container else {
            logger.error("ModelContainer not available for background affinity calculation.")
            return
        }

        Task { // Launch a new unstructured task, it will run off the MainActor by default
               // unless the operation it calls is isolated to another actor.
            await self.performBackgroundAffinityCalculation(modelContainer: modelContainer)
        }
    }

    @BackgroundActor // This method will run on the BackgroundActor
    private func performBackgroundAffinityCalculation(modelContainer: ModelContainer) async {
        let backgroundContext = ModelContext(modelContainer)
        // backgroundContext.autosaveEnabled = false // Optional: control saving manually

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
            .unlike: -0.5, .unrepost: -0.5, .manualUserAffinity: 5.0, .manualHashtagAffinity: 4.0, .dislikePost: -10.0
        ]

        var authorScores: [String: Double] = [:]
        var authorInteractionCounts: [String: Int] = [:]
        var tagScores: [String: Double] = [:]
        var tagInteractionCounts: [String: Int] = [:]

        for interaction in interactions {
            var currentScoreBoost = weights[interaction.actionType] ?? 0.0

            // Enhance like interactions with popularity
            if interaction.actionType == .like, let postIdString = interaction.statusID {
                // The Post model uses a String id
                let fetchDescriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postIdString })

                // Perform fetch within a do-catch block for error handling, though try? is used here for brevity
                if let likedPost = try? backgroundContext.fetch(fetchDescriptor).first {
                    let popularityFactor = 0.001 // Example factor
                    // Assuming Post model has these properties as Int. Cast to Double for calculation.
                    let totalPopularity = Double(likedPost.favouritesCount + likedPost.reblogsCount + likedPost.repliesCount)
                    currentScoreBoost += totalPopularity * popularityFactor
                    logger.debug("Popularity boost of \(totalPopularity * popularityFactor) applied to post \(postIdString) for like interaction.")
                } else {
                    logger.debug("Could not fetch Post with ID \(postIdString) for popularity boost calculation.")
                }
            }

            // Apply score to author affinity
            if let authorId = interaction.authorAccountID {
                authorScores[authorId, default: 0.0] += currentScoreBoost
                authorInteractionCounts[authorId, default: 0] += 1
            }

            // Apply score to tag affinity
            if let tags = interaction.tags, !tags.isEmpty {
                for tagName in tags {
                    tagScores[tagName, default: 0.0] += currentScoreBoost
                    tagInteractionCounts[tagName, default: 0] += 1
                }
            }
        }

        // Update UserAffinities
        for (authorId, calculatedScore) in authorScores {
            let count = authorInteractionCounts[authorId] ?? 0
            await self.updateUserAffinityOnBackground(authorAccountID: authorId, score: calculatedScore, interactionCount: count, context: backgroundContext)
        }
        logger.info("Background: Author affinities updated.")

        // Update HashtagAffinities
        for (tagName, calculatedScore) in tagScores {
            let count = tagInteractionCounts[tagName] ?? 0
            await self.updateHashtagAffinityOnBackground(tag: tagName, score: calculatedScore, interactionCount: count, context: backgroundContext)
        }
        logger.info("Background: Hashtag affinities updated.")

        // If autosaveEnabled was set to false for backgroundContext:
        // do {
        //     try backgroundContext.save()
        //     logger.info("Background: Affinity data saved successfully.")
        // } catch {
        //     logger.error("Background: Error saving affinity data: \(error.localizedDescription)")
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

    // These methods interact with modelContext, so they should be on an actor that can safely access it.
    // If RecommendationService is not @MainActor globally, these need to be.
    @MainActor
    func topRecommendations(limit: Int) async -> [String] {
        guard let currentContext = try? getContext() else { return [] } // getContext ensures modelContext is available
        logger.info("Fetching top recommendations (limit: \(limit))...")
        var recommendedPostIDs: Set<String> = []

        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        userAffinityDescriptor.fetchLimit = limit
        let topUserAffinities = (try? currentContext.fetch(userAffinityDescriptor)) ?? []

        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        hashtagAffinityDescriptor.fetchLimit = limit
        let topHashtagAffinities = (try? currentContext.fetch(hashtagAffinityDescriptor)) ?? []

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let postDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.createdAt >= sevenDaysAgo },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recentPosts = (try? currentContext.fetch(postDescriptor)) ?? []

        if recentPosts.isEmpty {
            logger.info("No recent posts found to generate recommendations.")
            return []
        }
        
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
            let timeSinceCreation = Date().timeIntervalSince(post.createdAt)
            let decayFactor = max(0, 1.0 - (timeSinceCreation / (7.0 * 24.0 * 60.0 * 60.0)))
            postScore *= decayFactor

            if postScore > 0.1 {
                 scoredPosts.append((post.id, postScore))
            }
        }
        
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

        var userAffinityDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let userAffinities = (try? currentContext.fetch(userAffinityDescriptor)) ?? []
        let userAffinityMap = Dictionary(uniqueKeysWithValues: userAffinities.map { ($0.authorAccountID, $0.score) })

        var hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
        let hashtagAffinities = (try? currentContext.fetch(hashtagAffinityDescriptor)) ?? []
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: hashtagAffinities.map { ($0.tag, $0.score) })
        
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

        let reorderedTimeline = scoredPostsTuples.sorted { $0.score > $1.score }.map { $0.post }
        
        logger.info("Timeline scoring complete.")
        return reorderedTimeline
    }

    @MainActor
    func getInterestScore(for postID: String, authorAccountID: String?, tags: [String]?) async -> Double {
        guard let currentContext = try? getContext() else { return 0.0 }
        var score: Double = 0.0

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

    @BackgroundActor
    func getInteractionSummary(forDays days: Int) async throws -> [InteractionType: Int] {
        let context = try getContext() // Use existing method to get ModelContext
        logger.info("Calculating interaction summary for the last \(days) days on BackgroundActor...")

        guard let summaryDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            logger.error("Background: Could not calculate summaryDate for interaction summary.")
            // Or throw a specific error
            throw AppError(type: .other("Could not calculate summary date."))
        }

        let predicate = #Predicate<Interaction> { interaction in
            interaction.timestamp >= summaryDate
        }

        let descriptor = FetchDescriptor<Interaction>(predicate: predicate)

        let interactions = try context.fetch(descriptor)

        if interactions.isEmpty {
            logger.info("Background: No interactions found for the last \(days) days.")
            return [:]
        }

        // Aggregate interactions by type
        var summary: [InteractionType: Int] = [:]
        for interaction in interactions {
            summary[interaction.actionType, default: 0] += 1
        }

        logger.info("Background: Interaction summary calculated with \(summary.count) types of interactions.")
        return summary
    }
}
