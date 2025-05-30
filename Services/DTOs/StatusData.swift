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
class PostData: Codable { // Changed from struct to class
    let id: String
    let content: String
    let created_at: String?
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
    let reblog: PostData? // This is now allowed because PostData is a class

    // Since PostData is now a class, we need an initializer if we were to create it manually.
    // However, for Codable conformance and decoding from JSON, this explicit init is not strictly
    // necessary if all properties are non-optional or have defaults, and are settable (vars or initialized).
    // But it's good practice for classes. For 'let' properties, they must be set in an init.
    init(id: String, content: String, created_at: String?, account: AccountData, media_attachments: [MediaAttachmentData], favourited: Bool?, reblogged: Bool?, reblogs_count: Int, favourites_count: Int, replies_count: Int, url: String?, uri: String?, visibility: String?, application: ApplicationData?, mentions: [MentionData]?, tags: [TagData]?, reblog: PostData?) {
        self.id = id
        self.content = content
        self.created_at = created_at
        self.account = account
        self.media_attachments = media_attachments
        self.favourited = favourited
        self.reblogged = reblogged
        self.reblogs_count = reblogs_count
        self.favourites_count = favourites_count
        self.replies_count = replies_count
        self.url = url
        self.uri = uri
        self.visibility = visibility
        self.application = application
        self.mentions = mentions
        self.tags = tags
        self.reblog = reblog
    }
    
    // Codable automatically synthesizes init(from: Decoder) and encode(to: Encoder)
    // for classes as well, provided all stored properties are Codable.

    /// Converts `PostData` to the app's `Post` model.
    func toPost(instanceURL: URL) -> Post? {
        let createdDate: Date
        if let createdAtString = created_at,
           let parsedDate = NetworkSessionManager.iso8601DateFormatter.date(from: createdAtString) {
            createdDate = parsedDate
        } else {
            print("Invalid or missing date format for post \(id), defaulting to current date.")
            createdDate = Date()
        }

        let acc = account.toAccount(instanceURL: instanceURL)
        let attachments = media_attachments.map { $0.toMediaAttachment() }
        let postMentions = mentions?.map { $0.toMention() } ?? []
        let postTags = tags?.map { $0.toTag() } ?? []
        
        let rebloggedPost = self.reblog?.toPost(instanceURL: instanceURL)

        return Post(
            id: id,
            content: content,
            createdAt: createdDate,
            account: acc,
            mediaAttachments: attachments,
            isFavourited: favourited ?? false,
            isReblogged: reblogged ?? false,
            reblogsCount: reblogs_count,
            favouritesCount: favourites_count,
            repliesCount: replies_count,
            mentions: postMentions,
            tags: postTags,
            card: nil,
            url: self.url,
            reblog: rebloggedPost
        )
    }
}

// MARK: - AccountData (remains a struct)
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

// MARK: - Supporting Models (remain structs)

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
        let verifiedDate = verified_at.flatMap {
            NetworkSessionManager.iso8601DateFormatter.date(from: $0)
        }
        
        return Field(
            name: name,
            value: value,
            verifiedAt: verifiedDate
        )
    }
}
