//
//  OnDeviceAIService.swift
//  Mustard
//
//  Created by Jules on 30/07/25.
//

import Foundation
import OSLog

// --- Hypothetical FoundationModels Framework ---
// NOTE: This is a mocked implementation of the hypothetical iOS 26 `FoundationModels` API
// as described in the user's prompt.

struct FoundationModelInput {
    // Features for the model
    let authorAffinity: Double
    let tagAffinityScore: Double
    let postPopularity: Double // e.g., combination of likes, reposts
    let timeSincePost: Double // Decay factor
}

// Mocked FoundationModel class
class FoundationModel {
    enum ModelError: Error {
        case modelNotFound
        case predictionFailed
    }

    // Mocks loading a model from the app bundle.
    static func load(name: String) throws -> FoundationModel {
        // In a real scenario, this would load a compiled Core ML model or similar.
        // For this simulation, we just return a new instance.
        if name.isEmpty { throw ModelError.modelNotFound }
        return FoundationModel()
    }

    /// Mocks predicting an engagement score.
    func predict(input: FoundationModelInput) throws -> Double {
        // This is the core of the "AI model". In this simulation, it's a simple heuristic
        // that combines the input features. A real model would have learned weights.
        // The weights are chosen to give priority to user affinities.
        let score = (input.authorAffinity * 0.5) +
                    (input.tagAffinityScore * 0.3) +
                    (input.postPopularity * 0.1) +
                    (input.timeSincePost * 0.1)

        // Simulate a small chance of failure.
        if Int.random(in: 0..<100) == 50 {
            throw ModelError.predictionFailed
        }

        return score
    }
}

// --- End of Hypothetical Framework ---


@MainActor
class OnDeviceAIService {

    private var engagementModel: FoundationModel?
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "OnDeviceAIService")

    init() {
        do {
            // Load the hypothetical pre-trained model from the app's bundle.
            self.engagementModel = try FoundationModel.load(name: "EngagementPredictor")
            logger.info("On-device engagement model loaded successfully.")
        } catch {
            logger.critical("Failed to load on-device engagement model: \(error.localizedDescription)")
            self.engagementModel = nil
        }
    }

    /// Generates an engagement score for a given post using the on-device model.
    ///
    /// - Parameters:
    ///   - post: The `Post` to be scored.
    ///   - userAffinities: A dictionary of author IDs to their affinity scores.
    ///   - tagAffinities: A dictionary of tag names to their affinity scores.
    /// - Returns: A `Double` representing the predicted engagement score.
    func getEngagementScore(
        for post: Post,
        userAffinities: [String: Double],
        tagAffinities: [String: Double]
    ) -> Double {
        guard let engagementModel = engagementModel else {
            logger.error("Engagement model not available. Returning a score of 0.")
            return 0.0
        }

        // 1. Calculate Author Affinity Feature
        let authorAffinity = userAffinities[post.account?.id ?? ""] ?? 0.0

        // 2. Calculate Tag Affinity Feature
        let tagScore = post.tags?.reduce(0.0) { partialResult, tag in
            partialResult + (tagAffinities[tag.name] ?? 0.0)
        } ?? 0.0

        // 3. Calculate Post Popularity Feature
        let popularity = Double(post.favouritesCount + post.reblogsCount + post.repliesCount) * 0.01

        // 4. Calculate Time Decay Feature
        let timeSinceCreation = max(0, Date().timeIntervalSince(post.createdAt))
        // Simple decay: score is higher for newer posts. Max age of 7 days.
        let timeDecay = 1.0 - (timeSinceCreation / (7 * 24 * 60 * 60))

        // 5. Construct the input for the model
        let modelInput = FoundationModelInput(
            authorAffinity: authorAffinity,
            tagAffinityScore: tagScore,
            postPopularity: popularity,
            timeSincePost: timeDecay
        )

        // 6. Get prediction from the model
        do {
            let score = try engagementModel.predict(input: modelInput)
            return max(0, score) // Ensure score is not negative
        } catch {
            logger.error("Failed to get prediction for post \(post.id): \(error.localizedDescription)")
            return 0.0
        }
    }
}
