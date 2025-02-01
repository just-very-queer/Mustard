//
//  PostActionService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class PostActionService {
    private let networkService: NetworkService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "PostActionService")

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func toggleLike(postID: String) async throws {
        do {
            try await networkService.postAction(for: postID, path: "/api/v1/statuses/\(postID)/favourite")
            logger.info("Post \(postID) like toggled successfully.")
        } catch {
            logger.error("Failed to toggle like for post \(postID): \(error.localizedDescription)")
            throw error
        }
    }

    func toggleRepost(postID: String) async throws {
        do {
            try await networkService.postAction(for: postID, path: "/api/v1/statuses/\(postID)/reblog")
            logger.info("Post \(postID) repost toggled successfully.")
        } catch {
            logger.error("Failed to toggle repost for post \(postID): \(error.localizedDescription)")
            throw error
        }
    }

    func comment(postID: String, content: String) async throws {
        let body: [String: String] = ["status": content, "in_reply_to_id": postID]
        do {
            // Assuming the API returns an empty response for comment action.
            // Use `Data.self` as responseType if the API does not return any data.
            _ = try await networkService.postData(endpoint: "/api/v1/statuses", body: body, responseType: Data.self)
            logger.info("Comment added to post \(postID) successfully.")
        } catch {
            logger.error("Failed to add comment for post \(postID): \(error.localizedDescription)")
            throw error
        }
    }
}
