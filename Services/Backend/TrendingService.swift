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

    /// Fetches trending hashtags from Mastodon with caching.
    /// - Parameter limit: The maximum number of tags to return. Defaults to 10.
    /// - Returns: An array of `Tag` objects representing trending hashtags.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingHashtags(limit: Int = 10) async throws -> [Tag] {
        logger.debug("Attempting to fetch trending hashtags (limit: \(limit))...")
        let cacheKey = CacheService.CacheKey.trendingTags.rawValue

        if let cachedTags: [TagData] = cacheService.load(forKey: cacheKey),
           let lastFetched = cacheService.fetchDate(forKey: cacheKey),
           Date().timeIntervalSince(lastFetched) < (15 * 60) {
            logger.info("Returning trending hashtags from cache.")
            return cachedTags.map { $0.toTag() }.prefix(limit).map { $0 }
        }

        logger.info("Cache miss or expired for trending hashtags. Fetching from network.")
        do {
            let tags = try await mastodonAPIService.fetchTrendingTags(limit: limit)
            cacheService.save(tags, forKey: cacheKey)
            logger.info("Successfully fetched and cached trending hashtags.")
            return tags.map { $0.toTag() }
        } catch let error as AppError {
            logger.error("Error fetching trending hashtags: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unexpected error while fetching trending hashtags: \(error.localizedDescription)")
            throw AppError.networkError(type: .unknown, message: error.localizedDescription)
        }
    }

    // MARK: - Fetch Trending Posts

    /// Fetches trending posts (statuses) from Mastodon with caching.
    /// - Parameter limit: The maximum number of posts to return. Defaults to 20.
    /// - Returns: An array of `Post` objects.
    /// - Throws: An `AppError` if fetching fails.
    func fetchTrendingPosts(limit: Int = 20) async throws -> [Post] {
        logger.debug("Attempting to fetch trending posts (limit: \(limit))...")
        let cacheKey = CacheService.CacheKey.trendingPosts.rawValue

        if let cachedPosts: [PostData] = cacheService.load(forKey: cacheKey),
           let lastFetched = cacheService.fetchDate(forKey: cacheKey),
           Date().timeIntervalSince(lastFetched) < (15 * 60) {
            logger.info("Returning trending posts from cache.")
            return cachedPosts.map { $0.toPost(using: NetworkSessionManager.shared.iso8601DateFormatter) }.prefix(limit).map { $0 }
        }

        logger.info("Cache miss or expired for trending posts. Fetching from network.")
        do {
            let posts = try await mastodonAPIService.fetchTrendingStatuses(limit: limit)
            cacheService.save(posts, forKey: cacheKey)
            logger.info("Successfully fetched and cached trending posts.")
            return posts.map { $0.toPost(using: NetworkSessionManager.shared.iso8601DateFormatter) }
        } catch let error as AppError {
            logger.error("Error fetching trending posts: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unexpected error while fetching trending posts: \(error.localizedDescription)")
            throw AppError.networkError(type: .unknown, message: error.localizedDescription)
        }
    }
}
