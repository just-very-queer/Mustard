//
//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

// Card model for representing link previews
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

/// Represents a Mastodon post, previously known as Status.
@Model
final class Post: Identifiable, Hashable, Codable, Equatable, @unchecked Sendable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var account: Account?
    var isFavourited: Bool
    var isReblogged: Bool
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int
    @Relationship(deleteRule: .cascade) var mediaAttachments: [MediaAttachment]
    var mentions: [Mention]?
    var url: String?
    private var tagsData: Data?
    // Ensure Tag itself is Codable. If Tag is an @Model, it should already be.
    // If Tag is a simple struct, ensure it conforms to Codable.
    var tags: [Tag]? {
        get {
            guard let data = tagsData else { return nil }
            do {
                return try JSONDecoder().decode([Tag].self, from: data)
            } catch {
                print("Error decoding tags: \(error)")
                return nil
            }
        }
        set {
            if let newValue = newValue {
                do {
                    tagsData = try JSONEncoder().encode(newValue)
                } catch {
                    print("Error encoding tags: \(error)")
                    tagsData = nil
                }
            } else {
                tagsData = nil
            }
        }
    }
    var card: Card? // This will now use the Card struct with 'summary'
    
    @Relationship(deleteRule: .cascade) var replies: [Post]? = []
    
    init(
        id: String,
        content: String,
        createdAt: Date,
        account: Account?,
        mediaAttachments: [MediaAttachment] = [],
        isFavourited: Bool = false,
        isReblogged: Bool = false,
        reblogsCount: Int = 0,
        favouritesCount: Int = 0,
        repliesCount: Int = 0,
        replies: [Post]? = nil,
        mentions: [Mention]? = nil,
        tags: [Tag]? = nil,
        card: Card? = nil,
        url: String? = nil
        
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
        self.tags = tags
        self.card = card
        self.url = url
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, account, mediaAttachments, replies, mentions, tags, url, card
        case isFavourited = "favourited"
        case isReblogged = "reblogged"
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case repliesCount = "replies_count"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.account = try container.decodeIfPresent(Account.self, forKey: .account)
        self.isFavourited = try container.decodeIfPresent(Bool.self, forKey: .isFavourited) ?? false
        self.isReblogged = try container.decodeIfPresent(Bool.self, forKey: .isReblogged) ?? false
        self.reblogsCount = try container.decodeIfPresent(Int.self, forKey: .reblogsCount) ?? 0
        self.favouritesCount = try container.decodeIfPresent(Int.self, forKey: .favouritesCount) ?? 0
        self.repliesCount = try container.decodeIfPresent(Int.self, forKey: .repliesCount) ?? 0
        self.mediaAttachments = try container.decodeIfPresent([MediaAttachment].self, forKey: .mediaAttachments) ?? []
        self.replies = try container.decodeIfPresent([Post].self, forKey: .replies) ?? []
        self.mentions = try container.decodeIfPresent([Mention].self, forKey: .mentions)
        if let tagsArray = try container.decodeIfPresent([Tag].self, forKey: .tags) {
            self.tags = tagsArray // Uses the computed property's setter
        } else {
            self.tags = nil
        }
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.card = try container.decodeIfPresent(Card.self, forKey: .card)
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encode(isReblogged, forKey: .isReblogged)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
        try container.encode(mediaAttachments, forKey: .mediaAttachments)
        try container.encodeIfPresent(replies, forKey: .replies)
        try container.encodeIfPresent(mentions, forKey: .mentions)
        try container.encodeIfPresent(self.tags, forKey: .tags) // Uses the computed property's getter
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(card, forKey: .card)
        
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(account)
        hasher.combine(createdAt)
        hasher.combine(replies)
        hasher.combine(url)
        hasher.combine(reblogsCount)
        hasher.combine(favouritesCount)
        hasher.combine(repliesCount)
        hasher.combine(mediaAttachments)
        hasher.combine(tags) // Add tags to hashable
        hasher.combine(card)
    }
    
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
        lhs.tags == rhs.tags &&
        lhs.url == rhs.url &&
        lhs.card == rhs.card
    }
}
