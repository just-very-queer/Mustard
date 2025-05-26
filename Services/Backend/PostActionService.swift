//
//  PostActionService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  UPDATED: Now uses MastodonAPIService exclusively
//

import Foundation
import OSLog

class PostActionService {
    private let mastodonAPIService: MastodonAPIService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "PostActionService")

    /// Initialize with MastodonAPIService instance
    init(mastodonAPIService: MastodonAPIService) {
        self.mastodonAPIService = mastodonAPIService
    }

    /// Toggle the like (favourite) status of a post
    /// - Parameter postID: The ID of the post
    /// - Returns: The updated `Post` object, or `nil` if not returned
    func toggleLike(postID: String) async throws -> Post? {
        do {
            let updatedPost = try await mastodonAPIService.favouritePost(postId: postID)
            logger.info("Post \(postID) like toggled successfully.")
            return updatedPost
        } catch {
            logger.error("Failed to toggle like for post \(postID): \(error.localizedDescription)")
            throw AppError(message: "Failed to like post", underlyingError: error)
        }
    }

    /// Toggle the repost (reblog) status of a post
    /// - Parameter postID: The ID of the post
    /// - Returns: The updated `Post` object, or `nil` if not returned
    func toggleRepost(postID: String) async throws -> Post? {
        do {
            let updatedPost = try await mastodonAPIService.reblogPost(postId: postID)
            logger.info("Post \(postID) repost toggled successfully.")
            return updatedPost
        } catch {
            logger.error("Failed to toggle repost for post \(postID): \(error.localizedDescription)")
            throw AppError(message: "Failed to repost", underlyingError: error)
        }
    }

    /// Post a reply/comment to a given post
    /// - Parameters:
    ///   - postID: The post being replied to
    ///   - content: The reply text
    /// - Returns: The new `Post` object
    func comment(postID: String, content: String) async throws -> Post {
        do {
            let reply = try await mastodonAPIService.postStatus(status: content, inReplyToId: postID)
            logger.info("Comment added to post \(postID) successfully.")
            return reply
        } catch {
            logger.error("Failed to comment on post \(postID): \(error.localizedDescription)")
            throw AppError(message: "Failed to comment", underlyingError: error)
        }
    }
}
