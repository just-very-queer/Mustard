//
//  Post+Actions.swift
//  Mustard
//
//  Created by Jules on 30/07/25.
//

import Foundation
import OSLog

// Using the existing protocol defined in the project
// We assume `PostActionServiceProtocol` is defined elsewhere and available.

@MainActor
extension Post {

    private static let logger = Logger(subsystem: "titan.mustard.app.ao", category: "Post+Actions")

    /// Toggles the like status of the post with optimistic UI updates.
    /// - Parameter service: The service responsible for performing the like/unlike action.
    /// - Throws: An error if the network request fails. The UI should handle this.
    func toggleLike(
        using service: PostActionServiceProtocol,
        recommendationService: RecommendationService,
        currentUserAccountID: String?
    ) async throws {

        // The post to modify is the actual content post, not the reblog wrapper.
        let targetPost = self.reblog ?? self

        // 1. Perform optimistic update on the target post's properties.
        let originalFavouritedState = targetPost.isFavourited
        let originalFavouritesCount = targetPost.favouritesCount

        targetPost.isFavourited.toggle()
        targetPost.favouritesCount += targetPost.isFavourited ? 1 : -1

        do {
            // 2. Call the backend service.
            let returnedPost = try await service.toggleLike(postID: targetPost.id)

            // 3. (Optional but good practice) Update with confirmed data.
            // If the server returns the updated post object, sync our local model.
            if let updatedPost = returnedPost {
                targetPost.isFavourited = updatedPost.isFavourited
                targetPost.favouritesCount = updatedPost.favouritesCount
                targetPost.reblogsCount = updatedPost.reblogsCount
                targetPost.repliesCount = updatedPost.repliesCount
            }

            // 4. Log the interaction for recommendations.
            recommendationService.logInteraction(
                statusID: targetPost.id,
                actionType: targetPost.isFavourited ? .like : .unlike,
                accountID: currentUserAccountID,
                authorAccountID: targetPost.account?.id,
                postURL: targetPost.url,
                tags: targetPost.tags?.compactMap { $0.name }
            )

        } catch {
            Self.logger.error("Failed to toggle like for post \(targetPost.id): \(error.localizedDescription)")
            // 5. Revert optimistic update on error.
            targetPost.isFavourited = originalFavouritedState
            targetPost.favouritesCount = originalFavouritesCount

            // 6. Re-throw the error for the view to handle.
            throw error
        }
    }

    /// Toggles the repost status of the post with optimistic UI updates.
    func toggleRepost(
        using service: PostActionServiceProtocol,
        recommendationService: RecommendationService,
        currentUserAccountID: String?
    ) async throws {

        let targetPost = self.reblog ?? self

        let originalRebloggedState = targetPost.isReblogged
        let originalReblogsCount = targetPost.reblogsCount

        targetPost.isReblogged.toggle()
        targetPost.reblogsCount += targetPost.isReblogged ? 1 : -1

        do {
            let returnedPost = try await service.toggleRepost(postID: targetPost.id)

            if let updatedPost = returnedPost {
                targetPost.isReblogged = updatedPost.isReblogged
                targetPost.reblogsCount = updatedPost.reblogsCount
                targetPost.isFavourited = updatedPost.isFavourited
                targetPost.favouritesCount = updatedPost.favouritesCount
            }

            recommendationService.logInteraction(
                statusID: targetPost.id,
                actionType: targetPost.isReblogged ? .repost : .unrepost,
                accountID: currentUserAccountID,
                authorAccountID: targetPost.account?.id,
                postURL: targetPost.url,
                tags: targetPost.tags?.compactMap { $0.name }
            )

        } catch {
            Self.logger.error("Failed to toggle repost for post \(targetPost.id): \(error.localizedDescription)")
            targetPost.isReblogged = originalRebloggedState
            targetPost.reblogsCount = originalReblogsCount
            throw error
        }
    }

    /// Posts a comment on the post with optimistic UI updates.
    func comment(
        with content: String,
        using service: PostActionServiceProtocol,
        recommendationService: RecommendationService,
        currentUserAccountID: String?
    ) async throws {

        let targetPost = self.reblog ?? self

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Or throw a specific error
            return
        }

        // Optimistic update for replies count
        let originalRepliesCount = targetPost.repliesCount
        targetPost.repliesCount += 1

        do {
            _ = try await service.comment(postID: targetPost.id, content: content)

            // The API might not return the updated parent post, so we rely on the
            // optimistic update for the count.

            recommendationService.logInteraction(
                statusID: targetPost.id,
                actionType: .comment,
                accountID: currentUserAccountID,
                authorAccountID: targetPost.account?.id,
                postURL: targetPost.url,
                tags: targetPost.tags?.compactMap { $0.name }
            )

        } catch {
            Self.logger.error("Failed to post comment on post \(targetPost.id): \(error.localizedDescription)")
            targetPost.repliesCount = originalRepliesCount
            throw error
        }
    }
}
