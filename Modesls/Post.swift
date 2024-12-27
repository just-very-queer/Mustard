//
//  Post.swift
//  Mustard
//
//  Created by Your Name on [Date].
//

import Foundation
import SwiftData

/// Represents a Mastodon post.
@Model
final class Post: Identifiable, Codable {
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
    
    // MARK: - Initializer (for SwiftData usage)
    
    init(id: String,
         content: String,
         createdAt: Date,
         account: Account,
         mediaAttachments: [MediaAttachment],
         isFavourited: Bool,
         isReblogged: Bool,
         reblogsCount: Int,
         favouritesCount: Int,
         repliesCount: Int) {
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
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdAt
        case account
        case mediaAttachments
        case isFavourited
        case isReblogged
        case reblogsCount
        case favouritesCount
        case repliesCount
    }
    
    // MARK: - Decodable
    
    /// Manual initializer for decoding `Post` from JSON.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.account = try container.decode(Account.self, forKey: .account)
        self.mediaAttachments = try container.decode([MediaAttachment].self, forKey: .mediaAttachments)
        self.isFavourited = try container.decode(Bool.self, forKey: .isFavourited)
        self.isReblogged = try container.decode(Bool.self, forKey: .isReblogged)
        self.reblogsCount = try container.decode(Int.self, forKey: .reblogsCount)
        self.favouritesCount = try container.decode(Int.self, forKey: .favouritesCount)
        self.repliesCount = try container.decode(Int.self, forKey: .repliesCount)
    }
    
    // MARK: - Encodable
    
    /// Manual method for encoding `Post` to JSON.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(account, forKey: .account)
        try container.encode(mediaAttachments, forKey: .mediaAttachments)
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encode(isReblogged, forKey: .isReblogged)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
    }
}

