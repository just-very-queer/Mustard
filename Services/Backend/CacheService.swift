//
//  CacheService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class CacheService {
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "CacheService")
    private let cacheQueue = DispatchQueue(label: "com.yourcompany.Mustard.CacheQueue", qos: .background)
    private let cacheDirectoryName = "com.yourcompany.Mustard.datacache"
    private let fileManager = FileManager.default

    func cachePosts(_ posts: [Post], forKey key: String) async {
        cacheQueue.async {
            guard let directory = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let cacheDirectoryURL = directory.appendingPathComponent(self.cacheDirectoryName)

            do {
                if !self.fileManager.fileExists(atPath: cacheDirectoryURL.path) {
                    try self.fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
                }

                let fileURL = cacheDirectoryURL.appendingPathComponent("\(key).json")
                let data = try JSONEncoder().encode(posts)
                try data.write(to: fileURL, options: [.atomic])
                self.logger.info("Cached posts to disk at: \(fileURL.path)")
            } catch {
                self.logger.error("Failed to cache posts: \(error.localizedDescription)")
            }
        }
    }

    func loadPostsFromCache(forKey key: String) async throws -> [Post] {
        return try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async {
                let fileURL = self.getCacheFileURL(for: key)

                guard let data = try? Data(contentsOf: fileURL) else {
                    self.logger.info("Cache not found for key: \(key)")
                    continuation.resume(throwing: AppError(mastodon: .cacheNotFound, underlyingError: nil))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    decoder.dateDecodingStrategy = .iso8601
                    let posts = try decoder.decode([Post].self, from: data)
                    self.logger.info("Loaded posts from cache for key: \(key)")
                    continuation.resume(returning: posts)
                } catch {
                    self.logger.error("Failed to decode posts from cache: \(error.localizedDescription)")
                    continuation.resume(throwing: AppError(mastodon: .decodingError, underlyingError: error))
                }
            }
        }
    }

    func clearCache(forKey key: String) async {
        cacheQueue.async {
            let fileURL = self.getCacheFileURL(for: key)
            do {
                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try self.fileManager.removeItem(at: fileURL)
                    self.logger.info("Cache cleared for key: \(key)")
                }
            } catch {
                self.logger.error("Failed to clear cache: \(error.localizedDescription)")
            }
        }
    }

    private func getCacheFileURL(for key: String) -> URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDirectoryURL = directory.appendingPathComponent(cacheDirectoryName)
        return cacheDirectoryURL.appendingPathComponent("\(key).json")
    }
}
