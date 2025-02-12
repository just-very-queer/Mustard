//
//  CacheService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

actor CacheService {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "CacheService")
    private let cacheDirectoryName = "titan.mustard.app.ao.datacache"
    private let fileManager = FileManager.default

    /// Caches posts to disk asynchronously.
    func cachePosts(_ posts: [Post], forKey key: String) async {
        do {
            let directory = getCacheDirectory()
            let fileURL = directory.appendingPathComponent("\(key).json")
            let data = try JSONEncoder().encode(posts)

            try data.write(to: fileURL, options: [.atomic])
            logger.info("Cached posts to disk at: \(fileURL.path)")
        } catch {
            logger.error("Failed to cache posts: \(error.localizedDescription)")
        }
    }

    /// Loads posts from the cache asynchronously.
    func loadPostsFromCache(forKey key: String) async throws -> [Post] {
        let fileURL = getCacheFileURL(for: key)

        // Check if the file exists before attempting to load
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            logger.error("Cache file for \(key) not found at path: \(fileURL.path)")
            // Throw a more specific error.  This is important!
            throw AppError(type: .mastodon(.cacheNotFound), underlyingError: nil)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let posts = try decoder.decode([Post].self, from: data)
            logger.info("Loaded posts from cache for key: \(key)")
            return posts
        } catch {
            logger.error("Failed to decode posts from cache: \(error.localizedDescription)")
             // It's generally a good idea to delete corrupted cache files.
            try? FileManager.default.removeItem(at: fileURL)
            throw AppError(type: .mastodon(.decodingError), underlyingError: error)
        }
    }

    /// Clears the cache for a specific key asynchronously.
    func clearCache(forKey key: String) async {
        let fileURL = getCacheFileURL(for: key)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                logger.info("Cache cleared for key: \(key)")
            }
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
        }
    }


    // MARK: - Helper Methods

    /// Retrieves the cache directory.
    private func getCacheDirectory() -> URL {
        guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Document directory not found")
        }

        let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)

        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
            } catch {
                fatalError("Failed to create cache directory: \(error.localizedDescription)")
            }
        }

        return cacheDirectoryURL
    }

    /// Constructs the file URL for a specific cache key.
    private func getCacheFileURL(for key: String) -> URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)
        return cacheDirectoryURL.appendingPathComponent("\(key).json")
    }
}
