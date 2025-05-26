import Foundation

// Define the protocol based on methods used by TimelineViewModel for post actions
protocol PostActionServiceProtocol {
    func toggleLike(postID: String, isCurrentlyFavourited: Bool) async throws -> Post?
    func toggleRepost(postID: String, isCurrentlyReblogged: Bool) async throws -> Post?
    func comment(postID: String, content: String) async throws -> Post? // Assuming it might return the new comment as a Post
    // Add other methods from PostActionService if they exist and are needed.
}
