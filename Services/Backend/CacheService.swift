//
//  CacheService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

@MainActor // Ensure main thread safety
final class CacheService: ObservableObject {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "CacheService")
    private let cacheDirectoryName = "titan.mustard.app.ao.datacache"
       private let fileManager = FileManager.default

       // Using NetworkService's shared jsonEncoder and jsonDecoder to avoid redundant declarations
    private let jsonEncoder = NetworkService.shared.jsonEncoder
    private let jsonDecoder = NetworkService.shared.jsonDecoder

    private lazy var cacheDirectoryURL: URL = {
           guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
               fatalError("Document directory not found")
           }
           
           let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)
           createDirectoryIfNeeded(at: cacheDirectoryURL)
           return cacheDirectoryURL
       }()

    // Observable properties
    @Published var lastPrefetchDate: Date?
    @Published var cacheSize: Int = 0

    private func createDirectoryIfNeeded(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create cache directory: \(error.localizedDescription)")
        }
    }

    /// Caches posts to disk asynchronously.
    func cachePosts(_ posts: [Post], forKey key: String) async {
        do {
            let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")
            let data = try jsonEncoder.encode(posts)
            try data.write(to: fileURL, options: [.atomic])
            logger.info("Cached posts to disk at: \(fileURL.path)")
        } catch {
            logger.error("Failed to cache posts: \(error.localizedDescription)")
        }
    }

    /// Loads posts from the cache asynchronously.
    func loadPostsFromCache(forKey key: String) async -> [Post] {
        let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")

        // Check if the file exists before attempting to load
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.info("Cache file for \(key) not found. Returning empty list.")
            return [] // Return an empty list instead of throwing an error
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let posts = try jsonDecoder.decode([Post].self, from: data)
            logger.info("Loaded posts from cache for key: \(key)")
            return posts
        } catch {
            logger.error("Failed to decode posts from cache: \(error.localizedDescription)")
            // Delete corrupted cache files
            try? fileManager.removeItem(at: fileURL)
            return [] // Return an empty list instead of throwing an error
        }
    }

    /// Clears the cache for a specific key asynchronously.
    func clearCache(forKey key: String) async {
        let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                logger.info("Cache cleared for key: \(key)")
            }
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }

    /// Prefetches and caches a specified number of posts for offline reading.
    func prefetchPosts(count: Int, forKey key: String) async {
        // Fetch posts from the network using the Mastodon API
        do {
            let posts = try await fetchPostsFromMastodon(count: count)
            await cachePosts(posts, forKey: key)
            logger.info("Prefetched and cached \(posts.count) posts for offline reading.")
        } catch {
            logger.error("Failed to prefetch posts: \(error.localizedDescription)")
        }
    }

    /// Fetches posts from the Mastodon API.
    private func fetchPostsFromMastodon(count: Int) async throws -> [Post] {
        // Use the NetworkService to fetch posts from the Mastodon API
        let networkService = NetworkService.shared

        // Example: Fetch posts from the home timeline
        let endpoint = "/api/v1/timelines/home"
        let url = try await networkService.endpointURL(endpoint)

        // Fetch the posts
        let posts: [Post] = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

        // Limit the number of posts to the requested count
        return Array(posts.prefix(count))
    }
}

