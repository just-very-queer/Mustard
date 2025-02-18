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

    /// Fetch trending posts (used in TimelineService to get the top posts)
    func fetchTopPosts() async throws -> [Post] {
        let cacheKey = "trendingPosts"

        // First, try fetching from cache
        let cachedPosts = await cacheService.loadPostsFromCache(forKey: cacheKey)
        if !cachedPosts.isEmpty {
            return cachedPosts
        } else {
            logger.info("Cache miss for top posts or error loading from cache")
        }

        // If cache is unavailable, fetch from the network
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/trends/statuses")
            
            // Configure a JSONDecoder that matches Mastodon API date format
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601  // Ensuring proper date decoding

            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

            // Cache the fetched posts for future use
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            }

            return fetchedPosts
        } catch let decodingError as DecodingError {
            logger.error("Decoding error while fetching top posts: \(decodingError)")
            handleDecodingError(decodingError)
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
        } catch {
            logger.error("Failed to fetch top posts: \(error.localizedDescription)")
            throw AppError(message: "Failed to fetch top posts", underlyingError: error)
        }
    }

    /// Logs and categorizes decoding errors
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

