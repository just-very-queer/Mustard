// Services/Backend/NetworkService/MastodonAPIServiceProtocol.swift
import Foundation

// Placeholder for PostVisibility enum. This might exist elsewhere in the model definitions.
// If it does, this duplicate definition should be removed and the existing one imported.
enum PostVisibility: String, Codable, CaseIterable {
    case `public` = "public"
    case unlisted = "unlisted"
    case `private` = "private" // Followers-only
    case direct = "direct"
}

// Assuming Post is a Decodable struct defined elsewhere.
// If not, it would need a placeholder definition for the protocol to compile.
// For example:
// struct Post: Decodable { /* ... properties ... */ }

protocol MastodonAPIServiceProtocol {
    func postStatus(status: String, visibility: PostVisibility, inReplyToId: String?) async throws -> Post
    // Add other methods from MastodonAPIService that ComposerViewModel or other ViewModels might need,
    // to ensure a consistent interface and improve testability.
    // For now, only adding postStatus as per the immediate requirement.

    func fetchStatuses(by_ids ids: [String]) async throws -> [Post] // New method
}

// Note: The `inReplyToId` parameter was added to the protocol to match the existing
// `postStatus` method in `MastodonAPIService.swift` more closely, while also
// incorporating the `visibility` parameter required by `ComposerViewModel`.
// The `ComposerViewModel` currently calls `postStatus(status: content, visibility: .public)`,
// so it doesn't pass `inReplyToId`. We'll need to adjust the call in `ComposerViewModel`
// to include `inReplyToId: nil` or make `inReplyToId` optional with a default value in the protocol/implementation.
// For now, making it optional in the protocol.
//
// The actual `Post` type would need to be defined/imported for this to compile in a real project.
// The `ComposerViewModel`'s call `mastodonAPIService.postStatus(status: content, visibility: .public)`
// will need to be updated to `mastodonAPIService.postStatus(status: content, visibility: .public, inReplyToId: nil)`
// to match this protocol signature.
