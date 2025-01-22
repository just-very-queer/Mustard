//
//  PostData.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

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
    /// - Parameter instanceURL: The Mastodon instance URL associated with this post.
    /// - Returns: A `Post` instance.
    func toPost(instanceURL: URL) -> Post {
        let acc = account.toAccount(instanceURL: instanceURL) // Use instanceURL here
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

    enum CodingKeys: String, CodingKey {
           case id, content, account, media_attachments, favourited, reblogged
           case reblogs_count = "reblogs_count"
           case favourites_count = "favourites_count"
           case replies_count = "replies_count"
           case created_at = "created_at" // Correct mapping
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

    /// Computed property to derive instanceURL from the account URL
    var instanceURL: URL? {
        guard let url = URL(string: self.url), let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }

    func toAccount(instanceURL: URL) -> Account {
        return Account(
            id: id,
            username: username,
            displayName: display_name,
            avatar: URL(string: avatar) ?? URL(string: "https://example.com/default_avatar.png")!,
            acct: acct,
            url: instanceURL, // Use instanceURL here
            accessToken: nil
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, acct, avatar, url
        case display_name = "display_name"
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
    
    enum CodingKeys: String, CodingKey {
        case id, type, url
    }
}
