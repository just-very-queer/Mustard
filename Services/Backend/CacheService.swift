//
//  CacheService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  UPDATED: Now uses MastodonAPIService and NetworkSessionManager
//

import Foundation
import OSLog

@MainActor
final class CacheService: ObservableObject {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "CacheService")
    private let cacheDirectoryName = "titan.mustard.app.ao.datacache"
    private let fileManager = FileManager.default

    private let jsonEncoder = NetworkSessionManager.shared.jsonEncoder
    private let jsonDecoder = NetworkSessionManager.shared.jsonDecoder
    private let mastodonAPIService: MastodonAPIService

    private lazy var cacheDirectoryURL: URL = {
        guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Document directory not found")
        }
        let url = directory.appendingPathComponent(cacheDirectoryName)
        createDirectoryIfNeeded(at: url)
        return url
    }()

    @Published var lastPrefetchDate: Date?
    @Published var cacheSize: Int = 0

    // MARK: - Init

    init(mastodonAPIService: MastodonAPIService) {
        self.mastodonAPIService = mastodonAPIService
    }

    // MARK: - Directory Handling

    private func createDirectoryIfNeeded(at url: URL) {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create cache directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Write

    func cachePosts(_ posts: [Post], forKey key: String) async {
        do {
            let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")
            let data = try jsonEncoder.encode(posts)
            try data.write(to: fileURL, options: [.atomic])
            logger.info("Cached \(posts.count) posts to disk at: \(fileURL.path)")
        } catch {
            logger.error("Failed to cache posts: \(error.localizedDescription)")
        }
    }

    // MARK: - Cache Read

    func loadPostsFromCache(forKey key: String) async -> [Post] {
        let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.info("No cache found for key '\(key)'. Returning empty array.")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let posts = try jsonDecoder.decode([Post].self, from: data)
            logger.info("Loaded \(posts.count) posts from cache for key: \(key)")
            return posts
        } catch {
            logger.error("Failed to decode cached posts: \(error.localizedDescription)")
            try? fileManager.removeItem(at: fileURL)
            return []
        }
    }

    // MARK: - Cache Clear

    func clearCache(forKey key: String) async {
        let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                logger.info("Cache cleared for key: \(key)")
            }
        } catch {
            logger.error("Failed to clear cache for key '\(key)': \(error.localizedDescription)")
        }
    }

    // MARK: - Prefetch & Background Caching

    func prefetchPosts(count: Int, forKey key: String, progress: @escaping (Double) -> Void) async {
        do {
            let posts = try await fetchPostsFromMastodon(count: count)
            await cachePosts(posts, forKey: key)
            progress(100.0)
            logger.info("Prefetched and cached \(posts.count) posts for key: \(key)")
        } catch {
            logger.error("Failed to prefetch posts: \(error.localizedDescription)")
        }
    }

    // MARK: - Post Fetch via Mastodon API

    private func fetchPostsFromMastodon(count: Int) async throws -> [Post] {
        return try await mastodonAPIService.fetchHomeTimeline(limit: count)
    }
}
