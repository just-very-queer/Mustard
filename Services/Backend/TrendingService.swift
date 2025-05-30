//
//  TrendingService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

/// Service responsible for fetching trending content like hashtags and posts.
@MainActor
final class TrendingService: ObservableObject {
    private let mastodonAPIService: MastodonAPIService
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TrendingService")

    init(mastodonAPIService: MastodonAPIService, cacheService: CacheService) {
        self.mastodonAPIService = mastodonAPIService
        self.cacheService = cacheService
        logger.info("TrendingService initialized with MastodonAPIService and CacheService.")
    }

    // MARK: - Fetch Trending Hashtags

    /// Fetches trending hashtags from Mastodon.
    /// - Parameter limit: The maximum number of tags to return. Note: The API endpoint used does not support a limit, so it will be applied after fetching.
    /// - Returns: An array of `Tag` objects representing trending hashtags.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingHashtags(limit: Int = 10) async throws -> [Tag] {
        logger.debug("Attempting to fetch trending hashtags (limit: \(limit))...")
        
        // NOTE: Caching logic has been removed as the current CacheService implementation does not support it.
        // This would be a good place to add caching back once CacheService is updated with generic capabilities.

        logger.info("Fetching trending hashtags from network.")
        do {
            let tags = try await mastodonAPIService.fetchTrendingTags()
            logger.info("Successfully fetched trending hashtags.")
            // The API service already returns [Tag], so we apply the limit manually.
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
    /// - Parameter limit: The maximum number of posts to return. Note: The API endpoint used does not support a limit, so it will be applied after fetching.
    /// - Returns: An array of `Post` objects.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingPosts(limit: Int = 20) async throws -> [Post] {
        logger.debug("Attempting to fetch trending posts (limit: \(limit))...")
        
        // NOTE: Caching logic has been removed.

        logger.info("Fetching trending posts from network.")
        do {
            let posts = try await mastodonAPIService.fetchTrendingStatuses()
            logger.info("Successfully fetched trending posts.")
            // The API service already returns [Post], so we apply the limit manually.
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
