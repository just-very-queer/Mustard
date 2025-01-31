//
//  User.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import SwiftData

// MARK: - Source
/// Represents the source data of a user's profile, containing privacy settings and other metadata.
struct Source: Codable {
    let privacy: String?
    let sensitive: Bool?
    let language: String?
    let note: String?
    let fields: [Field]
    let followRequestsCount: Int?

    enum CodingKeys: String, CodingKey {
        case privacy, sensitive, language, note, fields
        case followRequestsCount = "follow_requests_count"
    }
}

// MARK: - Field
/// Represents a custom profile field for a user.
struct Field: Codable {
    let name: String
    let value: String
    let verifiedAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, value
        case verifiedAt = "verified_at"
    }

    // Custom Date Decoding for verifiedAt
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)

        // Attempt to decode verifiedAt as a Date, handling nil or invalid formats gracefully
        if let verifiedAtString = try container.decodeIfPresent(String.self, forKey: .verifiedAt) {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: verifiedAtString) {
                verifiedAt = date
            } else {
                verifiedAt = nil
            }
        } else {
            verifiedAt = nil
        }
    }

    // Explicit initializer for `Field`
    init(name: String, value: String, verifiedAt: Date?) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }
}

// MARK: - Role
/// Represents a user's role with associated permissions.
struct Role: Codable, Identifiable {
    let id: String
    let name: String
    let permissions: String
}

// MARK: - Emoji
/// Represents a custom emoji, including URLs to its static and animated versions.
struct Emoji: Codable, Identifiable {
    let shortcode: String
    let url: URL
    let staticURL: URL
    let visibleInPicker: Bool
    let category: String?

    var id: String { shortcode }

    enum CodingKeys: String, CodingKey {
        case shortcode, url
        case staticURL = "static_url"
        case visibleInPicker = "visible_in_picker"
        case category
    }
}

// MARK: - User
/// Represents a user in the app, conforming to Identifiable, Codable, and Hashable protocols.
struct User: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let acct: String
    let display_name: String?  // Keep the key as 'display_name' for API compatibility
    let locked: Bool
    let bot: Bool
    let discoverable: Bool?
    let indexable: Bool?
    let group: Bool
    let created_at: Date
    let note: String?
    let url: String
    let avatar: String?
    let avatar_static: String?
    let header: String?
    let header_static: String?
    let followers_count: Int
    let following_count: Int
    let statuses_count: Int
    let last_status_at: String?
    let suspended: Bool?
    let hide_collections: Bool?
    let noindex: Bool?
    let source: Source?
    let emojis: [Emoji]
    let roles: [Role]?
    let fields: [Field]

    enum CodingKeys: String, CodingKey {
        case id, username, acct, locked, bot, discoverable, indexable, group, note, url, avatar, source, emojis, roles, fields
        case display_name = "display_name"  // Map 'display_name' from API to 'display_name' in User model
        case created_at = "created_at"
        case avatar_static = "avatar_static"
        case header_static = "header_static"
        case followers_count = "followers_count"
        case following_count = "following_count"
        case statuses_count = "statuses_count"
        case last_status_at = "last_status_at"
        case suspended
        case hide_collections = "hide_collections"
        case noindex
        case header
    }

    // MARK: - Initializer
    init(id: String, username: String, acct: String, display_name: String?, locked: Bool, bot: Bool, discoverable: Bool?, indexable: Bool?, group: Bool, created_at: Date, note: String?, url: String, avatar: String?, avatar_static: String?, header: String?, header_static: String?, followers_count: Int, following_count: Int, statuses_count: Int, last_status_at: String?, suspended: Bool?, hide_collections: Bool?, noindex: Bool?, source: Source?, emojis: [Emoji], roles: [Role]?, fields: [Field]) {
        self.id = id
        self.username = username
        self.acct = acct
        self.display_name = display_name
        self.locked = locked
        self.bot = bot
        self.discoverable = discoverable
        self.indexable = indexable
        self.group = group
        self.created_at = created_at
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatar_static = avatar_static
        self.header = header
        self.header_static = header_static
        self.followers_count = followers_count
        self.following_count = following_count
        self.statuses_count = statuses_count
        self.last_status_at = last_status_at
        self.suspended = suspended
        self.hide_collections = hide_collections
        self.noindex = noindex
        self.source = source
        self.emojis = emojis
        self.roles = roles
        self.fields = fields
    }

    // MARK: - Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        acct = try container.decode(String.self, forKey: .acct)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        locked = try container.decode(Bool.self, forKey: .locked)
        bot = try container.decode(Bool.self, forKey: .bot)
        discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
        indexable = try container.decodeIfPresent(Bool.self, forKey: .indexable)
        group = try container.decode(Bool.self, forKey: .group)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        url = try container.decode(String.self, forKey: .url)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        avatar_static = try container.decodeIfPresent(String.self, forKey: .avatar_static)
        header = try container.decodeIfPresent(String.self, forKey: .header)
        header_static = try container.decodeIfPresent(String.self, forKey: .header_static)
        followers_count = try container.decode(Int.self, forKey: .followers_count)
        following_count = try container.decode(Int.self, forKey: .following_count)
        statuses_count = try container.decode(Int.self, forKey: .statuses_count)
        last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at)
        suspended = try container.decodeIfPresent(Bool.self, forKey: .suspended)
        hide_collections = try container.decodeIfPresent(Bool.self, forKey: .hide_collections)
        noindex = try container.decodeIfPresent(Bool.self, forKey: .noindex)
        source = try container.decodeIfPresent(Source.self, forKey: .source)
        emojis = try container.decode([Emoji].self, forKey: .emojis)
        roles = try container.decodeIfPresent([Role].self, forKey: .roles)
        fields = try container.decode([Field].self, forKey: .fields)

        let createdAtString = try container.decode(String.self, forKey: .created_at)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: createdAtString) {
            created_at = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .created_at, in: container, debugDescription: "Date string does not match format expected by formatter.")
        }
    }

    // MARK: - Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(acct, forKey: .acct)
        try container.encode(display_name, forKey: .display_name)
        try container.encode(locked, forKey: .locked)
        try container.encode(bot, forKey: .bot)
        try container.encodeIfPresent(discoverable, forKey: .discoverable)
        try container.encodeIfPresent(indexable, forKey: .indexable)
        try container.encode(group, forKey: .group)
        try container.encode(note, forKey: .note)
        try container.encode(url, forKey: .url)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(avatar_static, forKey: .avatar_static)
        try container.encode(header, forKey: .header)
        try container.encode(header_static, forKey: .header_static)
        try container.encode(followers_count, forKey: .followers_count)
        try container.encode(following_count, forKey: .following_count)
        try container.encode(statuses_count, forKey: .statuses_count)
        try container.encode(last_status_at, forKey: .last_status_at)
        try container.encodeIfPresent(suspended, forKey: .suspended)
        try container.encodeIfPresent(hide_collections, forKey: .hide_collections)
        try container.encodeIfPresent(noindex, forKey: .noindex)
        try container.encode(source, forKey: .source)
        try container.encode(emojis, forKey: .emojis)
        try container.encode(roles, forKey: .roles)
        try container.encode(fields, forKey: .fields)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: created_at), forKey: .created_at)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

extension User {
    init(from account: Account) {
        self.id = account.id
        self.username = account.username
        self.acct = account.acct
        self.display_name = account.display_name
        self.locked = account.isLocked ?? false
        self.bot = account.isBot ?? false
        self.discoverable = account.discoverable
        self.indexable = true // Assuming this is true by default or set by your logic
        self.group = false // Assuming it's not a group user by default
        self.created_at = Date() // This can be updated as per your logic if you have a creation date
        self.note = account.note
        self.url = account.url.absoluteString
        self.avatar = account.avatar.absoluteString
        self.avatar_static = account.avatar.absoluteString // Update based on actual data
        self.header = account.header?.absoluteString
        self.header_static = account.header_static?.absoluteString
        self.followers_count = account.followers_count ?? 0
        self.following_count = account.following_count ?? 0
        self.statuses_count = account.statuses_count ?? 0
        self.last_status_at = account.last_status_at
        self.suspended = account.suspended ?? false
        self.hide_collections = false // Default to false or based on your logic
        self.noindex = false // Default to false
        self.source = nil // Add if needed, based on your logic
        self.emojis = [] // Add emojis if needed
        self.roles = [] // Add roles if needed
        self.fields = [] // Add fields if needed
    }
}
