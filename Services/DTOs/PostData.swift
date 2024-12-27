//
//  PostData.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Represents the data structure of a Mastodon post received from the API.
struct PostData: Codable {
    let id: String
    let content: String
    let created_at: String
    let account: AccountData
    let media_attachments: [MediaAttachmentData]
    let favourited: Bool?
    let reblogged: Bool?
    let reblogs_count: Int
    let favourites_count: Int
    let replies_count: Int

    /// Converts `PostData` to the app's `Post` model.
    func toPost() -> Post {
        let acc = account.toAccount()
        let attachments = media_attachments.map { $0.toMediaAttachment() }

        return Post(
            id: id,
            content: content,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            account: acc,
            mediaAttachments: attachments,
            isFavourited: favourited ?? false,
            isReblogged: reblogged ?? false,
            reblogsCount: reblogs_count,
            favouritesCount: favourites_count,
            repliesCount: replies_count
        )
    }
}

/// Represents the account data within a Mastodon post.
struct AccountData: Codable {
    let id: String
    let username: String
    let display_name: String
    let avatar: String
    let acct: String
    let url: String

    /// Converts `AccountData` to the app's `Account` model.
    /// - Returns: An `Account` instance.
    func toAccount() -> Account {
        return Account(
            id: id,
            username: username,
            displayName: display_name,
            avatar: URL(string: avatar) ?? URL(string: "https://example.com/default_avatar.png")!,
            acct: acct,
            instanceURL: URL(string: url) ?? URL(string: "https://mastodon.social")!,
            accessToken: "defaultAccessToken" // Assign appropriately
        )
    }
}

/// Represents the media attachment data within a Mastodon post.
struct MediaAttachmentData: Codable {
    let id: String
    let type: String
    let url: String

    /// Converts `MediaAttachmentData` to the app's `MediaAttachment` model.
    /// - Returns: A `MediaAttachment` instance.
    func toMediaAttachment() -> MediaAttachment {
        return MediaAttachment(
            id: id,
            type: MediaAttachment.MediaType(rawValue: type.lowercased()) ?? .unknown,
            url: URL(string: url) ?? URL(string: "https://example.com")!
        )
    }
}

