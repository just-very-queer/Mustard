//
//  TrendingService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog
import Observation

/// Service responsible for fetching trending content like hashtags and posts.
@MainActor
@Observable
final class TrendingService {
    private let mastodonAPIService: MastodonAPIService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TrendingService")

    init(mastodonAPIService: MastodonAPIService) {
        self.mastodonAPIService = mastodonAPIService
        logger.info("TrendingService initialized with MastodonAPIService.")
    }

    // MARK: - Fetch Trending Hashtags

    /// Fetches trending hashtags from Mastodon.
    /// - Parameter limit: The maximum number of tags to return.
    /// - Returns: An array of `Tag` objects representing trending hashtags.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingHashtags(limit: Int = 10) async throws -> [Tag] {
        logger.debug("Attempting to fetch trending hashtags (limit: \(limit))...")
        do {
            let tags = try await mastodonAPIService.fetchTrendingTags()
            logger.info("Successfully fetched trending hashtags.")
            return Array(tags.prefix(limit))
        } catch let error as AppError {
            logger.error("Error fetching trending hashtags: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unexpected error while fetching trending hashtags: \(error.localizedDescription)")
            throw AppError(type: .other("Unexpected error fetching trending hashtags"), underlyingError: error)
        }
    }

    // MARK: - Fetch Trending Posts

    /// Fetches trending posts (statuses) from Mastodon.
    /// - Parameter limit: The maximum number of posts to return.
    /// - Returns: An array of `Post` objects.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingPosts(limit: Int = 20) async throws -> [Post] {
        logger.debug("Attempting to fetch trending posts (limit: \(limit))...")
        do {
            let posts = try await mastodonAPIService.fetchTrendingStatuses()
            logger.info("Successfully fetched trending posts.")
            return Array(posts.prefix(limit))
        } catch let error as AppError {
            logger.error("Error fetching trending posts: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unexpected error while fetching trending posts: \(error.localizedDescription)")
            throw AppError(type: .other("Unexpected error fetching trending posts"), underlyingError: error)
        }
    }
}
