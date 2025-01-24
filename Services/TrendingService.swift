//
//   TrendingService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class TrendingService {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "TrendingService")

    init(networkService: NetworkService, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func fetchTrendingPosts() async throws -> [Post] {
        let cacheKey = "trendingPosts"

        if let cachedPosts = await cacheService.loadPostsFromCache(forKey: cacheKey) {
            return cachedPosts
        }

        do {
            let url = try NetworkService.shared.endpointURL("/api/v1/trends/statuses")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            return fetchedPosts
        } catch {
            logger.error("Failed to fetch trending posts: \(error.localizedDescription)")
            throw error
        }
    }
}
