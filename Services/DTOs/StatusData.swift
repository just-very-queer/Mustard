//
//  StatusData.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

// MARK: - PostData

/// Represents the data structure of a Mastodon post received from the API.
struct PostData: Codable {
    let id: String
    let content: String
    let created_at: String? // Keep as String for manual parsing
    let account: AccountData
    let media_attachments: [MediaAttachmentData]
    let favourited: Bool?
    let reblogged: Bool?
    let reblogs_count: Int
    let favourites_count: Int
    let replies_count: Int
    let url: String?
    let uri: String?
    let visibility: String?
    let application: ApplicationData?
    let mentions: [MentionData]?
    let tags: [TagData]?

    /// Converts `PostData` to the app's `Post` model.
    func toPost(instanceURL: URL) -> Post? {
        // Decode createdAt safely
        let createdDate: Date
        if let createdAtString = created_at,
           let parsedDate = NetworkSessionManager.iso8601DateFormatter.date(from: createdAtString) { // Using NetworkSessionManager
            createdDate = parsedDate
        } else {
            print("Invalid or missing date format for post \(id), defaulting to current date.")
            createdDate = Date() // Default value if key is missing or invalid
        }

        let acc = account.toAccount(instanceURL: instanceURL)
        let attachments = media_attachments.map { $0.toMediaAttachment() }
        let postMentions = mentions?.map { $0.toMention() } ?? []
        let postTags = tags?.map { $0.toTag() } ?? []

        return Post(
            id: id,
            content: content,
            createdAt: createdDate, // Always valid
            account: acc,
            mediaAttachments: attachments,
            isFavourited: favourited ?? false,
            isReblogged: reblogged ?? false,
            reblogsCount: reblogs_count,
            favouritesCount: favourites_count,
            repliesCount: replies_count,
            mentions: postMentions,
            tags: postTags
        )
    }
}

// MARK: - AccountData

/// Represents the account data within a Mastodon post.
struct AccountData: Codable {
    let id: String
    let username: String
    let display_name: String?
    let avatar: String
    let acct: String
    let url: String
    let followers_count: Int?
    let following_count: Int?
    let statuses_count: Int?
    let last_status_at: String?
    let bot: Bool?
    let locked: Bool?
    let note: String?
    let header: String?
    let header_static: String?
    let created_at: String?
    let emojis: [EmojiData]?
    let fields: [FieldData]?
    let discoverable: Bool?
    let suspended: Bool?

    /// Converts `AccountData` to the app's `Account` model.
    func toAccount(instanceURL: URL) -> Account {
        return Account(
            id: id,
            username: username,
            display_name: display_name ?? username,
            avatar: URL(string: avatar, relativeTo: instanceURL) ?? URL(string: "https://example.com/default_avatar.png")!,
            acct: acct,
            url: URL(string: url, relativeTo: instanceURL)!,
            accessToken: nil,
            followers_count: followers_count,
            following_count: following_count,
            statuses_count: statuses_count,
            last_status_at: last_status_at,
            isBot: bot,
            isLocked: locked,
            note: note,
            header: URL(string: header ?? "", relativeTo: instanceURL),
            header_static: URL(string: header_static ?? "", relativeTo: instanceURL)
        )
    }
}

// MARK: - Supporting Models

struct MediaAttachmentData: Codable {
    let id: String
    let type: String
    let url: String

    func toMediaAttachment() -> MediaAttachment {
        return MediaAttachment(
            id: id,
            type: MediaAttachment.MediaType(rawValue: type.lowercased()) ?? .unknown,
            url: URL(string: url) ?? URL(string: "https://example.com")!
        )
    }
}

struct ApplicationData: Codable {
    let name: String
    let website: String?

    func toApplication() -> Application {
        return Application(name: name, website: website != nil ? URL(string: website!) : nil)
    }
}

struct MentionData: Codable {
    let id: String
    let username: String
    let url: String
    let acct: String

    func toMention() -> Mention {
        return Mention(id: id, username: username, url: URL(string: url)!, acct: acct)
    }
}

struct TagData: Codable {
    let name: String
    let url: String

    func toTag() -> Tag {
        return Tag(name: name, url: URL(string: url)!)
    }
}

struct EmojiData: Codable {
    let shortcode: String
    let url: String
    let static_url: String
    let visible_in_picker: Bool?

    func toEmoji() -> Emoji {
        return Emoji(
            shortcode: shortcode,
            url: URL(string: url)!,
            staticURL: URL(string: static_url)!,
            visibleInPicker: visible_in_picker ?? true,
            category: nil
        )
    }
}

struct FieldData: Codable {
    let name: String
    let value: String
    let verified_at: String?

    func toField() -> Field {
        // Use centralized date formatter for verification date
        let verifiedDate = verified_at.flatMap {
            NetworkSessionManager.iso8601DateFormatter.date(from: $0) // Using NetworkSessionManager
        }
        
        return Field(
            name: name,
            value: value,
            verifiedAt: verifiedDate
        )
    }
}
