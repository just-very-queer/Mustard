//
//  TimelineService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class TimelineService {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "TimelineService")

    init(networkService: NetworkService, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func fetchTimeline(useCache: Bool = true) async throws -> [Post] {
        let cacheKey = "timeline"

        if useCache {
            do {
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: cacheKey)
                // Perform background refresh in a separate Task
                Task {
                    await backgroundRefreshTimeline()
                }
                return cachedPosts
            } catch let error as AppError {
                if case .mastodon(.cacheNotFound) = error.type {
                    logger.info("Timeline cache not found on disk. Fetching from network.")
                } else {
                    logger.error("Error loading timeline from cache: \(error.localizedDescription)")
                    throw error
                }
            } catch {
                logger.error("Error loading timeline from cache: \(error.localizedDescription)")
                throw error
            }
        }

        // Fetch from network if not using cache or cache not found
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            // Use Task to perform cache operation concurrently
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            }
            return fetchedPosts
        } catch {
            logger.error("Failed to fetch timeline: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchMoreTimeline(page: Int) async throws -> [Post] {
        var endpoint = "/api/v1/timelines/home"
        if page > 1 {
            do {
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: "timeline")
                if let lastID = cachedPosts.last?.id {
                    endpoint += "?max_id=\(lastID)"
                }
            } catch {
                logger.error("Error loading timeline from cache: \(error.localizedDescription)")
            }
        }

        let url = try await NetworkService.shared.endpointURL(endpoint)
        let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

        if !fetchedPosts.isEmpty {
            // Use Task to perform cache operation concurrently
            Task {
                do {
                    let updatedPosts = (try await cacheService.loadPostsFromCache(forKey: "timeline")) + fetchedPosts
                    await cacheService.cachePosts(updatedPosts, forKey: "timeline")
                } catch {
                    logger.error("Error updating timeline cache: \(error.localizedDescription)")
                }
            }
        }

        return fetchedPosts
    }

    func backgroundRefreshTimeline() async {
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            if !fetchedPosts.isEmpty {
                // Use Task to perform cache operation concurrently
                Task {
                    await cacheService.cachePosts(fetchedPosts, forKey: "timeline")
                }
            }
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
        }
    }
}
