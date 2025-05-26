//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

/// Represents a Mastodon post, previously known as Status.
@Model
final class Post: Identifiable, Hashable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var account: Account?
    var isFavourited: Bool // Renamed from 'favourited' for clarity and consistency
    var isReblogged: Bool // Renamed from 'reblogged' for clarity and consistency
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int
    @Relationship(deleteRule: .cascade) var mediaAttachments: [MediaAttachment]
    var mentions: [Mention]? // Added mentions
    var url: String?
    var tags: [Tag]?  // Added tags
    
    
    // MARK: - Relationship (Replies) - Note: Direct nested decoding of replies might be complex
    @Relationship(deleteRule: .cascade) var replies: [Post]? = [] // Initialize as optional and empty array
    
    // MARK: - Initializer
    init(
        id: String,
        content: String,
        createdAt: Date,
        account: Account?, // Account can be optional in relationship
        mediaAttachments: [MediaAttachment] = [],
        isFavourited: Bool = false,
        isReblogged: Bool = false,
        reblogsCount: Int = 0,
        favouritesCount: Int = 0,
        repliesCount: Int = 0,
        replies: [Post]? = nil, // Replies can be nil or empty array
        mentions: [Mention]? = nil, // Added mentions to init
        tags: [Tag]? = nil // Added tags to init
        
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.account = account
        self.isFavourited = isFavourited
        self.isReblogged = isReblogged
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.repliesCount = repliesCount
        self.mediaAttachments = mediaAttachments
        self.replies = replies
        self.mentions = mentions
        self.tags = tags // Initialize tags
    }
    
    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, account, mediaAttachments, replies, mentions, tags, url
        case isFavourited = "favourited" // Corrected to "favourited" as per Mastodon API
        case isReblogged = "reblogged" // Corrected to "reblogged" as per Mastodon API
        case reblogsCount = "reblogs_count" // Corrected to snake_case
        case favouritesCount = "favourites_count" // Corrected to snake_case
        case repliesCount = "replies_count" // Corrected to snake_case
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.account = try container.decodeIfPresent(Account.self, forKey: .account)
        self.isFavourited = try container.decodeIfPresent(Bool.self, forKey: .isFavourited) ?? false // Decode with default value
        self.isReblogged = try container.decodeIfPresent(Bool.self, forKey: .isReblogged) ?? false
        self.reblogsCount = try container.decodeIfPresent(Int.self, forKey: .reblogsCount) ?? 0
        self.favouritesCount = try container.decodeIfPresent(Int.self, forKey: .favouritesCount) ?? 0 // Decode with default value
        self.repliesCount = try container.decodeIfPresent(Int.self, forKey: .repliesCount) ?? 0
        self.mediaAttachments = try container.decodeIfPresent([MediaAttachment].self, forKey: .mediaAttachments) ?? [] // Decode with default value
        self.replies = try container.decodeIfPresent([Post].self, forKey: .replies) ?? [] // Decode replies as optional, default to empty array
        self.mentions = try container.decodeIfPresent([Mention].self, forKey: .mentions) // Decode with default value
        self.tags = try container.decodeIfPresent([Tag].self, forKey: .tags) // Decode tags
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(account, forKey: .account) // Encode optional account
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encode(isReblogged, forKey: .isReblogged)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
        try container.encode(mediaAttachments, forKey: .mediaAttachments)
        try container.encodeIfPresent(replies, forKey: .replies) // Encode optional replies
        try container.encodeIfPresent(mentions, forKey: .mentions)
        try container.encodeIfPresent(tags, forKey: .tags) // Encode tags
        try container.encodeIfPresent(url, forKey: .url)
        
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(account) // Account must be Hashable
        hasher.combine(createdAt)
        hasher.combine(replies) // [Post] must be Hashable (recursive Hashable conformance!)
        hasher.combine(url)
        hasher.combine(reblogsCount)
        hasher.combine(favouritesCount)
        hasher.combine(repliesCount)
        hasher.combine(mediaAttachments) // [MediaAttachment] must be Hashable
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.createdAt == rhs.createdAt &&
        lhs.account == rhs.account &&
        lhs.isFavourited == rhs.isFavourited &&
        lhs.isReblogged == rhs.isReblogged &&
        lhs.reblogsCount == rhs.reblogsCount &&
        lhs.favouritesCount == rhs.favouritesCount &&
        lhs.repliesCount == rhs.repliesCount &&
        lhs.mediaAttachments == rhs.mediaAttachments &&
        lhs.mentions == rhs.mentions &&
        lhs.tags == rhs.tags && // Compare tags
        lhs.url == rhs.url
        // Note: 'replies' relationship is intentionally omitted from Equatable to avoid potential infinite recursion.
    }
}

