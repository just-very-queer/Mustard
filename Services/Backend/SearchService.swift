//
//  SearchService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import Combine
import os

/// Service responsible for handling search-related operations.
@MainActor
final class SearchService: ObservableObject {
    private let mastodonAPIService: MastodonAPIService
    private let logger = Logger(subsystem: "com.mustard.Mustard", category: "SearchService")

    /// Initializes a new instance of the search service.
    /// - Parameter mastodonAPIService: The service for making API calls to Mastodon.
    init(mastodonAPIService: MastodonAPIService) {
        self.mastodonAPIService = mastodonAPIService
        self.logger.info("SearchService initialized with MastodonAPIService.")
    }

    /// Performs a search query.
    func search(
        query: String,
        type: String? = nil,
        limit: Int = 20,
        resolve: Bool = false,
        excludeUnreviewed: Bool = false,
        accountId: String? = nil,
        maxId: String? = nil,
        minId: String? = nil,
        offset: Int? = nil
    ) async throws -> SearchResults {
        self.logger.debug("Searching for query: '\(query)', type: \(type ?? "any")")
        do {
            let results = try await mastodonAPIService.search(
                query: query,
                type: type,
                limit: limit,
                resolve: resolve,
                excludeUnreviewed: excludeUnreviewed,
                accountId: accountId,
                maxId: maxId,
                minId: minId,
                offset: offset
            )
            self.logger.info("Successfully fetched search results for query: '\(query)'")
            return results
        } catch let error as AppError {
            self.logger.error("Error searching for query '\(query)': \(error.localizedDescription)")
            throw error
        } catch {
            self.logger.error("An unexpected error occurred while searching for query '\(query)': \(error.localizedDescription)")
            throw AppError(network: .networkError, underlyingError: error)
        }
    }

    /// Fetches trending hashtags.
    func fetchTrendingHashtags(limit: Int? = nil) async throws -> [Tag] {
        self.logger.debug("Fetching trending hashtags.")
        do {
            let tags = try await mastodonAPIService.fetchTrendingTags()
            self.logger.info("Successfully fetched \(tags.count) trending hashtags.")
            return tags
        } catch let error as AppError {
            self.logger.error("Error fetching trending hashtags: \(error.localizedDescription)")
            throw error
        } catch {
            self.logger.error("An unexpected error occurred while fetching trending hashtags: \(error.localizedDescription)")
            throw AppError(network: .networkError, underlyingError: error)
        }
    }

    /// Fetches posts for a specific hashtag.
    func fetchHashtagPosts(hashtag: String, maxId: String? = nil, limit: Int? = nil) async throws -> [Post] {
        self.logger.debug("Fetching posts for hashtag: #\(hashtag)")
        do {
            let posts = try await mastodonAPIService.fetchHashtagTimeline(
                hashtag: hashtag
            )
            self.logger.info("Successfully fetched \(posts.count) posts for hashtag: #\(hashtag)")
            return posts
        } catch let error as AppError {
            self.logger.error("Error fetching posts for hashtag #\(hashtag): \(error.localizedDescription)")
            throw error
        } catch {
            self.logger.error("An unexpected error occurred while fetching posts for hashtag #\(hashtag): \(error.localizedDescription)")
            throw AppError(network: .networkError, underlyingError: error)
        }
    }
}

/// Represents a single entry of a hashtag's historical usage.
struct TagHistory: Decodable {
    var day: String
    var uses: String
    var accounts: String
}
