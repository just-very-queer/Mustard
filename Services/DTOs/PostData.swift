//
//  PostData.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

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

struct AccountData: Codable {
    let id: String
    let username: String
    let display_name: String
    let avatar: String

    func toAccount() -> Account {
        return Account(
            id: id,
            username: username,
            displayName: display_name,
            avatar: URL(string: avatar) ?? URL(string: "https://example.com")!,
            acct: username // Adjust if needed for Mastodon 'acct'
        )
    }
}

struct MediaAttachmentData: Codable {
    let id: String
    let type: String
    let url: String

    func toMediaAttachment() -> MediaAttachment {
        return MediaAttachment(
            id: id,
            type: type,
            url: URL(string: url) ?? URL(string: "https://example.com")!
        )
    }
}
