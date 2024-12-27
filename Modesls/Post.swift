//
//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

/// Represents a Mastodon post.
@Model
final class Post: Identifiable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date
    var account: Account
    var mediaAttachments: [MediaAttachment]
    var isFavourited: Bool
    var isReblogged: Bool
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int

    // MARK: - Initializers

    /// Initializes a Post with all properties.
    /// - Parameters:
    ///   - id: The unique identifier for the post.
    ///   - content: The content of the post.
    ///   - createdAt: The creation date of the post.
    ///   - account: The account that created the post.
    ///   - mediaAttachments: An array of media attachments associated with the post.
    ///   - isFavourited: Indicates if the post is favourited.
    ///   - isReblogged: Indicates if the post is reblogged.
    ///   - reblogsCount: The number of reblogs.
    ///   - favouritesCount: The number of favourites.
    ///   - repliesCount: The number of replies.
    init(id: String, content: String, createdAt: Date, account: Account, mediaAttachments: [MediaAttachment], isFavourited: Bool, isReblogged: Bool, reblogsCount: Int, favouritesCount: Int, repliesCount: Int) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.account = account
        self.mediaAttachments = mediaAttachments
        self.isFavourited = isFavourited
        self.isReblogged = isReblogged
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.repliesCount = repliesCount
    }
}

