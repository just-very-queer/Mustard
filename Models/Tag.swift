import Foundation
import SwiftData // If it might become a @Model in the future, though not currently.

// Based on the definition used in RecommendedTimelineView_Previews
// and assumptions for Post.tags
struct Tag: Codable, Hashable, Identifiable {
    var id: String { name } // Assuming name is unique for Identifiable
    let name: String
    let url: String? // Optional URL, consistent with Mastodon API for Tag

    // If Tag were a @Model, it would look different:
    // @Model
    // final class Tag {
    //     @Attribute(.unique) var name: String
    //     var url: String?
    //     // Relationships to Posts if needed
    //
    //     init(name: String, url: String? = nil) {
    //         self.name = name
    //         self.url = url
    //     }
    // }
    // For now, using the struct version as Post.swift uses [Tag]? where Tag is Codable.
    // If Post.tags were a relationship to @Model Tag, Post's Tag type would be `[Tag]?` or `PersistentModel<[Tag]>`.
    // The current Post model has `var tags: [Tag]?` and `Tag` is decoded via `Codable`.
}
