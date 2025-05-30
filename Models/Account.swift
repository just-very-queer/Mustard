//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

@Model
class Account: Identifiable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var username: String
    var display_name: String?
    var avatar: URL?
    var acct: String
    var url: URL?
    var accessToken: String? = nil
    var followers_count: Int?
    var following_count: Int?
    var statuses_count: Int?
    var last_status_at: String?
    var isBot: Bool?
    var isLocked: Bool?
    var note: String?
    var header: URL?
    var header_static: URL?
    var discoverable: Bool?
    var indexable: Bool?
    var suspended: Bool?

    // Inverse relationship: An Account can have many Posts.
    // Post.account is the 'to-one' side. This is the 'to-many' side.
    @Relationship(deleteRule: .cascade, inverse: \Post.account)
    var posts: [Post]? = []

    var instanceURL: URL? {
        guard let url = url, let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }

    // MARK: - Initializer
    init(
        id: String, username: String, display_name: String?, avatar: URL?, acct: String, url: URL?,
        accessToken: String? = nil, followers_count: Int? = nil, following_count: Int? = nil,
        statuses_count: Int? = nil, last_status_at: String? = nil, isBot: Bool? = nil,
        isLocked: Bool? = nil, note: String? = nil, header: URL? = nil, header_static: URL? = nil,
        discoverable: Bool? = nil, indexable: Bool? = nil, suspended: Bool? = nil,
        posts: [Post]? = [] // Added posts to initializer
    ) {
        self.id = id
        self.username = username
        self.display_name = display_name
        self.avatar = avatar
        self.acct = acct
        self.url = url
        self.accessToken = accessToken
        self.followers_count = followers_count
        self.following_count = following_count
        self.statuses_count = statuses_count
        self.last_status_at = last_status_at
        self.isBot = isBot
        self.isLocked = isLocked
        self.note = note
        self.header = header
        self.header_static = header_static
        self.discoverable = discoverable
        self.indexable = indexable
        self.suspended = suspended
        self.posts = posts // Initialize posts
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        // 'posts' is a relationship managed by SwiftData, not typically part of Account JSON
        case id, username, acct, avatar, url, accessToken, note, header, discoverable, indexable, suspended
        case display_name, followers_count, following_count, statuses_count, last_status_at
        case isBot = "bot"
        case isLocked = "locked"
        case header_static
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        avatar = try container.decodeIfPresent(URL.self, forKey: .avatar)
        acct = try container.decode(String.self, forKey: .acct)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        followers_count = try container.decodeIfPresent(Int.self, forKey: .followers_count)
        following_count = try container.decodeIfPresent(Int.self, forKey: .following_count)
        statuses_count = try container.decodeIfPresent(Int.self, forKey: .statuses_count)
        last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at)
        isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        header = try container.decodeIfPresent(URL.self, forKey: .header)
        header_static = try container.decodeIfPresent(URL.self, forKey: .header_static)
        discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
        indexable = try container.decodeIfPresent(Bool.self, forKey: .indexable)
        suspended = try container.decodeIfPresent(Bool.self, forKey: .suspended)
        // `posts` is not decoded from JSON here, it's managed by SwiftData relationships
        posts = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        // ... encode other properties ...
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(display_name, forKey: .display_name)
        // ... and so on for all properties in CodingKeys ...
        // Do not encode 'posts' as it's a SwiftData managed relationship.
    }
    
    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }

    // toUser() extension method remains the same
}

extension Account {
    func toUser() -> User { // Ensure User struct is defined elsewhere
        return User( /* ... mapping ... */
            id: self.id,
            username: self.username,
            acct: self.acct,
            display_name: self.display_name ?? self.username,
            locked: self.isLocked ?? false,
            bot: self.isBot ?? false,
            discoverable: self.discoverable ?? false,
            indexable: self.indexable ?? false,
            group: false,
            created_at: Date(), // Or parse from a string if available
            note: self.note ?? "",
            url: self.url?.absoluteString ?? "",
            avatar: self.avatar?.absoluteString ?? "",
            avatar_static: self.avatar?.absoluteString ?? "",
            header: self.header?.absoluteString ?? "",
            header_static: self.header_static?.absoluteString ?? "",
            followers_count: self.followers_count ?? 0,
            following_count: self.following_count ?? 0,
            statuses_count: self.statuses_count ?? 0,
            last_status_at: self.last_status_at ?? "",
            suspended: self.suspended ?? false,
            hide_collections: false,
            noindex: false,
            source: nil,
            emojis: [],
            roles: [],
            fields: []
        )
    }
}
