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

    // Fetch trending posts (used in TimelineService to get the top posts)
    func fetchTopPosts() async throws -> [Post] {
        let cacheKey = "trendingPosts"

        do {
            // Try to load cached posts
            let cachedPosts = try await cacheService.loadPostsFromCache(forKey: cacheKey)
            return cachedPosts
        } catch {
            // Log the error as info since it might just be a cache miss
            logger.info("Cache miss for top posts or error loading from cache: \(error.localizedDescription)")
        }

        // If no cached posts are found or an error occurred, fetch them from the network
        do {
            // Construct the URL for the trending posts endpoint
            let url = try await NetworkService.shared.endpointURL("/api/v1/trends/statuses")
            
            // Fetch data from the network
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            
            // Cache the fetched posts for future use in a non-blocking Task
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            }
            
            return fetchedPosts
        } catch {
            // Log the error if fetching from the network fails
            logger.error("Failed to fetch top posts: \(error.localizedDescription)")
            throw error
        }
    }
}

