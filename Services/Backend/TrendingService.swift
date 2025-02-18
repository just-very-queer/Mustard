//
//  TrendingService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class TrendingService {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TrendingService")

    init(networkService: NetworkService, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    // MARK: - Fetch Trending Hashtags

    /// Fetches trending hashtags from the Mastodon API.
    /// - Returns: An array of `Post` objects representing trending hashtags.
    /// - Throws: `AppError` if the request fails.
    func fetchTrendingHashtags() async throws -> [Post] {
        let cacheKey = "trendingHashtags"
        return try await fetchTrendingData(endpoint: "/api/v1/trends", cacheKey: cacheKey)
    }

    // MARK: - Fetch Top Posts

    /// Fetches trending posts (used in TimelineService to get the top posts).
    /// - Returns: An array of `Post` objects representing trending posts.
    /// - Throws: `AppError` if the request fails.
    func fetchTopPosts() async throws -> [Post] {
        let cacheKey = "trendingPosts"
        return try await fetchTrendingData(endpoint: "/api/v1/trends/statuses", cacheKey: cacheKey)
    }

    // MARK: - Helper Methods

    /// Fetches trending data (hashtags or posts) from the network or cache.
    /// - Parameters:
    ///   - endpoint: The API endpoint to fetch data from.
    ///   - cacheKey: The cache key to use for storing/retrieving data.
    /// - Returns: An array of `Post` objects.
    /// - Throws: `AppError` if the request fails.
    private func fetchTrendingData(endpoint: String, cacheKey: String) async throws -> [Post] {
        // First, try fetching from cache
        let cachedPosts = await cacheService.loadPostsFromCache(forKey: cacheKey)
        if !cachedPosts.isEmpty {
            logger.info("Cache hit for \(cacheKey)")
            return cachedPosts
        } else {
            logger.info("Cache miss for \(cacheKey) or error loading from cache")
        }

        // If cache is unavailable, fetch from the network
        do {
            let url = try await networkService.endpointURL(endpoint)
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

            // Cache the fetched posts for future use
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            }

            logger.info("Successfully fetched and cached \(fetchedPosts.count) posts for \(cacheKey)")
            return fetchedPosts
        } catch let decodingError as DecodingError {
            logger.error("Decoding error while fetching trending data: \(decodingError)")
            handleDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch {
            logger.error("Failed to fetch trending data: \(error.localizedDescription)")
            throw AppError(message: "Failed to fetch trending data", underlyingError: error)
        }
    }

    /// Logs and categorizes decoding errors.
    private func handleDecodingError(_ error: DecodingError) {
        switch error {
        case .dataCorrupted(let context):
            logger.error("Data corrupted: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            logger.error("Value of type '\(type)' not found: \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            logger.error("Type '\(type)' mismatch: \(context.debugDescription)")
        @unknown default:
            logger.error("Unknown decoding error")
        }
    }
}
