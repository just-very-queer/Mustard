//
//  RecommendationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import Foundation
import SwiftData
import OSLog
import Observation

@globalActor
actor BackgroundActor {
    static let shared = BackgroundActor()
}

@MainActor
@Observable
class RecommendationService {
    static let shared = RecommendationService()

    internal var modelContext: ModelContext?
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "RecommendationService")

    private init() {
        logger.info("RecommendationService instance created.")
    }

    func configure(modelContext: ModelContext) {
        if self.modelContext == nil {
            self.modelContext = modelContext
            self.modelContext?.autosaveEnabled = true
            logger.info("RecommendationService ModelContext configured.")

            Task {
                await calculateAffinities()
            }
        } else {
            logger.info("RecommendationService ModelContext already configured.")
        }
    }

    public func getContext() throws -> ModelContext {
        guard let context = modelContext else {
            let errorMsg = "RecommendationService ModelContext not configured."
            logger.critical("\(errorMsg, privacy: .public)")
            throw AppError(type: .other(errorMsg))
        }
        return context
    }

    // MARK: - Interaction Logging

    func logInteraction(
        statusID: String? = nil,
        actionType: InteractionType,
        accountID: String? = nil,
        authorAccountID: String? = nil,
        postURL: String? = nil,
        tags: [String]? = nil,
        viewDuration: Double? = nil,
        linkURL: String? = nil
    ) {
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
        logger.info("Logged interaction: \(actionType.rawValue, privacy: .public) for status \(statusID ?? "N/A", privacy: .public).")
    }

    // MARK: - Affinity Calculation with Mathematical Time Decay

    @MainActor
    func calculateAffinities() async {
        logger.info("Starting affinity calculation (triggered on MainActor)...")
        guard let modelContainer = self.modelContext?.container else {
            logger.error("ModelContainer not available for background affinity calculation.")
            return
        }

        Task {
            await self.performBackgroundAffinityCalculation(modelContainer: modelContainer)
        }
    }

    @BackgroundActor
    private func performBackgroundAffinityCalculation(modelContainer: ModelContainer) async {
        let backgroundContext = ModelContext(modelContainer)
        logger.info("Performing background affinity calculation on BackgroundActor...")

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let interactionDescriptor = FetchDescriptor<Interaction>(
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
            .like: 1.0,
            .comment: 3.0,
            .repost: 2.0,
            .linkOpen: 1.5,
            .view: 0.2,
            .unlike: -0.5,
            .unrepost: -0.5,
            .manualUserAffinity: 5.0,
            .manualHashtagAffinity: 4.0,
            .dislikePost: -10.0
        ]

        var authorScores: [String: Double] = [:]
        var authorInteractionCounts: [String: Int] = [:]
        var tagScores: [String: Double] = [:]
        var tagInteractionCounts: [String: Int] = [:]

        let now = Date()
        let maxAgeInSeconds = 30.0 * 86400.0 // 30 days

        for interaction in interactions {
            var baseScore = weights[interaction.actionType] ?? 0.0

            if interaction.actionType == .like, let postIdString = interaction.statusID {
                let fetchDescriptor = FetchDescriptor<Post>(predicate: #Predicate { $0.id == postIdString })
                if let likedPost = try? backgroundContext.fetch(fetchDescriptor).first {
                    let popularity = Double(likedPost.favouritesCount + likedPost.reblogsCount + likedPost.repliesCount)
                    baseScore += popularity * 0.001
                }
            }

            // Exponential / linear time decay
            let ageInSeconds = min(now.timeIntervalSince(interaction.timestamp), maxAgeInSeconds)
            var decayMultiplier = 1.0 - (ageInSeconds / maxAgeInSeconds)
            decayMultiplier = max(0.0, min(1.0, decayMultiplier))

            let currentScoreBoost = baseScore * decayMultiplier

            if let authorId = interaction.authorAccountID {
                authorScores[authorId, default: 0.0] += currentScoreBoost
                authorInteractionCounts[authorId, default: 0] += 1
            }

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
            await self.updateUserAffinityOnBackground(
                authorAccountID: authorId,
                score: calculatedScore,
                interactionCount: count,
                context: backgroundContext
            )
        }

        // Update HashtagAffinities
        for (tagName, calculatedScore) in tagScores {
            let count = tagInteractionCounts[tagName] ?? 0
            await self.updateHashtagAffinityOnBackground(
                tag: tagName,
                score: calculatedScore,
                interactionCount: count,
                context: backgroundContext
            )
        }

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

    // MARK: - Recommendation & Scoring API

    /// Computes interest score for an individual post using user and tag affinities
    @MainActor
    func getInterestScore(
        for post: Post,
        userAffinities: [String: Double],
        tagAffinities: [String: Double]
    ) -> Double {
        // 1. Author Affinity
        let authorAffinity = userAffinities[post.account?.id ?? ""] ?? 0.0

        // 2. Tag Affinity
        let tagScore = post.tags?.reduce(0.0) { sum, tag in
            sum + (tagAffinities[tag.name] ?? 0.0)
        } ?? 0.0

        // 3. Post Popularity
        let popularity = Double(post.favouritesCount + post.reblogsCount + post.repliesCount) * 0.01

        // 4. Time Decay Factor (Freshness bonus)
        let timeSinceCreation = max(0, Date().timeIntervalSince(post.createdAt))
        let timeDecay = max(0.0, 1.0 - (timeSinceCreation / (7.0 * 86400.0)))

        // Weighted composite score
        let score = (authorAffinity * 0.5) + (tagScore * 0.3) + (popularity * 0.1) + (timeDecay * 0.1)
        return max(0.0, score)
    }

    @MainActor
    func topRecommendations(limit: Int) async -> [String] {
        guard let currentContext = try? getContext() else { return [] }
        logger.info("Fetching top recommendations (limit: \(limit))...")

        let userAffinities = (try? currentContext.fetch(FetchDescriptor<UserAffinity>())) ?? []
        let userAffinityMap = Dictionary(uniqueKeysWithValues: userAffinities.map { ($0.authorAccountID, $0.score) })

        let hashtagAffinities = (try? currentContext.fetch(FetchDescriptor<HashtagAffinity>())) ?? []
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: hashtagAffinities.map { ($0.tag, $0.score) })

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let postDescriptor = FetchDescriptor<Post>(
            predicate: #Predicate { $0.createdAt >= sevenDaysAgo },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recentPosts = (try? currentContext.fetch(postDescriptor)) ?? []

        if recentPosts.isEmpty {
            return []
        }

        let scoredPosts = recentPosts.map { post in
            let score = getInterestScore(for: post, userAffinities: userAffinityMap, tagAffinities: hashtagAffinityMap)
            return (postID: post.id, score: score)
        }

        let recommendedPostIDs = scoredPosts.sorted { $0.score > $1.score }
                                          .prefix(limit)
                                          .map { $0.postID }

        return Array(recommendedPostIDs)
    }

    @MainActor
    func scoredTimeline(_ timeline: [Post]) async -> [Post] {
        guard let currentContext = try? getContext(), !timeline.isEmpty else { return timeline }

        let userAffinities = (try? currentContext.fetch(FetchDescriptor<UserAffinity>())) ?? []
        let userAffinityMap = Dictionary(uniqueKeysWithValues: userAffinities.map { ($0.authorAccountID, $0.score) })

        let hashtagAffinities = (try? currentContext.fetch(FetchDescriptor<HashtagAffinity>())) ?? []
        let hashtagAffinityMap = Dictionary(uniqueKeysWithValues: hashtagAffinities.map { ($0.tag, $0.score) })

        let scoredPostsTuples = timeline.map { post -> (post: Post, score: Double) in
            let score = getInterestScore(for: post, userAffinities: userAffinityMap, tagAffinities: hashtagAffinityMap)
            return (post, score)
        }

        return scoredPostsTuples.sorted { $0.score > $1.score }.map { $0.post }
    }

    @MainActor
    func getInterestScore(for postID: String, authorAccountID: String?, tags: [String]?) async -> Double {
        guard let currentContext = try? getContext() else { return 0.0 }
        var score: Double = 0.0

        if let authorAccountID = authorAccountID, !authorAccountID.isEmpty {
            let userAffinityDescriptor = FetchDescriptor<UserAffinity>(predicate: #Predicate { $0.authorAccountID == authorAccountID })
            if let userAffinity = try? currentContext.fetch(userAffinityDescriptor).first {
                score += userAffinity.score
            }
        }

        if let postTags = tags, !postTags.isEmpty {
            for tagName in postTags {
                let hashtagAffinityDescriptor = FetchDescriptor<HashtagAffinity>(predicate: #Predicate { $0.tag == tagName })
                if let hashtagAffinity = try? currentContext.fetch(hashtagAffinityDescriptor).first {
                    score += hashtagAffinity.score
                }
            }
        }

        return score
    }

    func getInteractionSummary(forDays days: Int) async throws -> [InteractionType: Int] {
        let context = try getContext()
        guard let summaryDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            throw AppError(type: .other("Could not calculate summary date."))
        }

        let predicate = #Predicate<Interaction> { interaction in
            interaction.timestamp >= summaryDate
        }

        let descriptor = FetchDescriptor<Interaction>(predicate: predicate)
        let interactions = try context.fetch(descriptor)

        var summary: [InteractionType: Int] = [:]
        for interaction in interactions {
            summary[interaction.actionType, default: 0] += 1
        }
        return summary
    }
}
