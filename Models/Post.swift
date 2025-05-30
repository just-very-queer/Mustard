//
//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

// Card model for representing link previews (ensure this struct definition is correct as previously provided)
// struct Card: Codable, Hashable, Equatable { ... } // Assuming this is correct from previous steps

struct Card: Codable, Hashable, Equatable {
    let url: String
    let title: String
    let summary: String // RENAMED from 'description'
    let type: String
    let image: String?
    let authorName: String?
    let authorUrl: String?
    let providerName: String?
    let providerUrl: String?
    let html: String?
    let width: Int?
    let height: Int?
    let embedUrl: String?
    let blurhash: String?

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case summary = "description" // MAP 'summary' to JSON key "description"
        case type
        case image
        case authorName = "author_name"
        case authorUrl = "author_url"
        case providerName = "provider_name"
        case providerUrl = "provider_url"
        case html
        case width
        case height
        case embedUrl = "embed_url"
        case blurhash
    }
}

@Model
final class Post: Identifiable, Hashable, Codable, Equatable, @unchecked Sendable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date

    // Relationship to Account (Author of this post OR the reblogger if this post instance IS a reblog)
    // An Account can have many Posts. A Post is authored by one Account.
    // This is the 'to-one' side from Post's perspective. Inverse is on Account.posts.
    @Relationship(deleteRule: .nullify)
    var account: Account?

    // Relationship to MediaAttachments
    // A Post can have many MediaAttachments. A MediaAttachment belongs to one Post.
    // This is the 'to-many' side from Post's perspective. Inverse is on MediaAttachment.post.
    @Relationship(deleteRule: .cascade, inverse: \MediaAttachment.post)
    var mediaAttachments: [MediaAttachment]? = []

    // --- Self-Referential for Replies ---
    // If this Post *is* a reply, it replies to one parent Post.
    // This is the 'to-one' side (child pointing to parent). Inverse is on parent's 'replies' list.
    @Relationship(deleteRule: .nullify) // If parent is deleted, this reply is no longer "to" it.
    var inReplyTo: Post?

    // If this Post *is* a parent, it has many replies (children Posts).
    // This is the 'to-many' side (parent pointing to children). Inverse is on child's 'inReplyTo'.
    @Relationship(deleteRule: .cascade, inverse: \Post.inReplyTo)
    var replies: [Post]? = []

    // --- Self-Referential for Reblogs ---
    // If this Post instance *is* a reblog (a "wrapper" status),
    // this 'reblog' property points to the ORIGINAL Post that was reblogged.
    // This is a 'to-one' relationship (wrapper -> original). Inverse is on original's 'rebloggedBy' list.
    @Relationship(deleteRule: .cascade) // If original post is deleted, this reblog wrapper might be less meaningful.
    var reblog: Post?

    // If this Post instance *is* an original post,
    // this 'rebloggedBy' property lists all the "wrapper" Posts that are reblogs OF THIS original post.
    // This is a 'to-many' relationship (original -> wrappers). Inverse is on wrapper's 'reblog' property.
    @Relationship(deleteRule: .cascade, inverse: \Post.reblog)
    var rebloggedBy: [Post]? = []

    // Other properties
    var isFavourited: Bool
    var isReblogged: Bool
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int
    var mentions: [Mention]? // Assuming Mention is a simple Codable struct/class, not a @Model with complex inverse.
    var url: String?
    
    private var tagsData: Data?
    var tags: [Tag]? { // Assuming Tag is a @Model or a simple Codable struct
        get { tagsData.flatMap { try? JSONDecoder().decode([Tag].self, from: $0) } }
        set { tagsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    var card: Card?

    // Initializer
    init(id: String, content: String, createdAt: Date, account: Account? = nil,
         mediaAttachments: [MediaAttachment]? = [],
         isFavourited: Bool = false, isReblogged: Bool = false,
         reblogsCount: Int = 0, favouritesCount: Int = 0, repliesCount: Int = 0,
         mentions: [Mention]? = nil, tags: [Tag]? = nil, card: Card? = nil, url: String? = nil,
         inReplyTo: Post? = nil, replies: [Post]? = [],
         reblog: Post? = nil, rebloggedBy: [Post]? = []) {
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
        self.mentions = mentions
        self.tags = tags
        self.card = card
        self.url = url
        self.inReplyTo = inReplyTo
        self.replies = replies
        self.reblog = reblog
        self.rebloggedBy = rebloggedBy
    }

    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey {
        case id, content, createdAt, account, mediaAttachments, mentions, url, card, reblog
        case tagsData = "tags" // If your JSON for tags directly contains an array of Tag objects, map 'tags' to 'tagsData' and handle encoding/decoding
        case isFavourited = "favourited"
        case isReblogged = "reblogged"
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case repliesCount = "replies_count"
        // We don't typically decode 'inReplyTo', 'replies', 'rebloggedBy' from the primary post JSON.
        // 'inReplyTo' might come from an 'in_reply_to_id' and require resolution.
        // 'replies' and 'rebloggedBy' are usually established via inverse relationships by SwiftData.
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        account = try container.decodeIfPresent(Account.self, forKey: .account)
        mediaAttachments = try container.decodeIfPresent([MediaAttachment].self, forKey: .mediaAttachments) ?? []
        isFavourited = try container.decodeIfPresent(Bool.self, forKey: .isFavourited) ?? false
        isReblogged = try container.decodeIfPresent(Bool.self, forKey: .isReblogged) ?? false
        reblogsCount = try container.decodeIfPresent(Int.self, forKey: .reblogsCount) ?? 0
        favouritesCount = try container.decodeIfPresent(Int.self, forKey: .favouritesCount) ?? 0
        repliesCount = try container.decodeIfPresent(Int.self, forKey: .repliesCount) ?? 0
        mentions = try container.decodeIfPresent([Mention].self, forKey: .mentions)
        
        // If "tags" in JSON is an array of Tag objects and Tag is Codable:
        if let decodedTags = try container.decodeIfPresent([Tag].self, forKey: .tagsData) {
             self.tags = decodedTags
        } else {
             self.tags = nil // Or initialize self.tagsData if JSON directly provides that
        }

        url = try container.decodeIfPresent(String.self, forKey: .url)
        card = try container.decodeIfPresent(Card.self, forKey: .card)
        reblog = try container.decodeIfPresent(Post.self, forKey: .reblog)

        // Initialize relationship fields not typically in primary JSON to empty/nil
        inReplyTo = nil // This would be set later if resolved from an ID
        replies = []
        rebloggedBy = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encodeIfPresent(mediaAttachments, forKey: .mediaAttachments)
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encode(isReblogged, forKey: .isReblogged)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
        try container.encodeIfPresent(mentions, forKey: .mentions)
        // If 'tags' is the property to encode and it's an array of Tag objects:
        try container.encodeIfPresent(tags, forKey: .tagsData)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(card, forKey: .card)
        try container.encodeIfPresent(reblog, forKey: .reblog)
        // Do not encode 'inReplyTo', 'replies', 'rebloggedBy' if they are managed by SwiftData
        // inverses and not part of the primary object structure you'd send to an API.
    }

    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id // For simplicity, or compare more fields if necessary
    }
}
