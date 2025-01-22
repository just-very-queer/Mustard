//
//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

/// Represents a Mastodon post.
@Model
final class Post: Identifiable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date
    var account: Account
    var isFavourited: Bool
    var isReblogged: Bool
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int
    var mediaAttachments: [MediaAttachment]

    // MARK: - Initializer
    init(
        id: String,
        content: String,
        createdAt: Date,
        account: Account,
        mediaAttachments: [MediaAttachment] = [],
        isFavourited: Bool = false,
        isReblogged: Bool = false,
        reblogsCount: Int = 0,
        favouritesCount: Int = 0,
        repliesCount: Int = 0
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
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, account, mediaAttachments, isFavourited, isReblogged, reblogsCount, favouritesCount, repliesCount
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.account = try container.decode(Account.self, forKey: .account)
        self.isFavourited = try container.decode(Bool.self, forKey: .isFavourited)
        self.isReblogged = try container.decode(Bool.self, forKey: .isReblogged)
        self.reblogsCount = try container.decode(Int.self, forKey: .reblogsCount)
        self.favouritesCount = try container.decode(Int.self, forKey: .favouritesCount)
        self.repliesCount = try container.decode(Int.self, forKey: .repliesCount)
        self.mediaAttachments = try container.decode([MediaAttachment].self, forKey: .mediaAttachments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(account, forKey: .account)
        try container.encode(isFavourited, forKey: .isFavourited)
        try container.encode(isReblogged, forKey: .isReblogged)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
        try container.encode(mediaAttachments, forKey: .mediaAttachments)
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
            lhs.mediaAttachments == rhs.mediaAttachments
    }
}
