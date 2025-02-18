//
// User.swift
// Mustard
//
// Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import SwiftData

// MARK: - Source
struct Source: Codable {
    let privacy: String?
    let sensitive: Bool?
    let language: String?
    let note: String?
    let fields: [Field]? // Make fields optional as per targeted decoding approach, if not always present
    let followRequestsCount: Int?

    enum CodingKeys: String, CodingKey {
        case privacy, sensitive, language, note, fields
        case followRequestsCount = "follow_requests_count"
    }
}

// MARK: - Field
struct Field: Codable {
    let name: String
    let value: String
    let verifiedAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, value
        case verifiedAt = "verified_at"
    }

    // Custom Date Decoding for verifiedAt - Keep as it handles date format variations
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

    // Explicit initializer for `Field` - Keep for manual creation if needed
    init(name: String, value: String, verifiedAt: Date?) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }
}

// MARK: - Role
struct Role: Codable, Identifiable {
    let id: String
    let name: String
    let permissions: String? // Make permissions optional, might not always be present
}

// MARK: - Emoji
struct Emoji: Codable, Identifiable {
    let shortcode: String
    let url: URL? // Make URL optional, handle potential missing URLs gracefully
    let staticURL: URL? // Make staticURL optional for robustness
    let visibleInPicker: Bool? // Make visibleInPicker optional
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
struct User: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let acct: String
    let display_name: String?
    let locked: Bool? // Make locked optional
    let bot: Bool? // Make bot optional
    let discoverable: Bool?
    let indexable: Bool?
    let group: Bool? // Make group optional
    let created_at: Date? // Now an optional Date - Keep optional
    let note: String?
    let url: String? // Make url optional, handle potential missing URLs gracefully
    let avatar: String?
    let avatar_static: String?
    let header: String?
    let header_static: String?
    let followers_count: Int? // Make followers_count optional
    let following_count: Int? // Make following_count optional
    let statuses_count: Int? // Make statuses_count optional
    let last_status_at: String?
    let suspended: Bool?
    let hide_collections: Bool?
    let noindex: Bool?
    let source: Source?
    let emojis: [Emoji]? // Make emojis optional, if not always present
    let roles: [Role]?
    let fields: [Field]? // Make fields optional, if not always present

    enum CodingKeys: String, CodingKey {
        case id, username, acct, locked, bot, discoverable, indexable, group, note, url, avatar, source, emojis, roles, fields
        case display_name = "display_name"
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

    // MARK: - Initializer - Keep initializer for manual creation if needed
    init(id: String, username: String, acct: String, display_name: String?, locked: Bool?, bot: Bool?, discoverable: Bool?, indexable: Bool?, group: Bool?, created_at: Date?, note: String?, url: String?, avatar: String?, avatar_static: String?, header: String?, header_static: String?, followers_count: Int?, following_count: Int?, statuses_count: Int?, last_status_at: String?, suspended: Bool?, hide_collections: Bool?, noindex: Bool?, source: Source?, emojis: [Emoji]?, roles: [Role]?, fields: [Field]?) {
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

    // MARK: - Decoder (Corrected) - Keep decoder as it is, using decodeIfPresent and handling optional date
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        acct = try container.decode(String.self, forKey: .acct)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked)
        bot = try container.decodeIfPresent(Bool.self, forKey: .bot)
        discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
        indexable = try container.decodeIfPresent(Bool.self, forKey: .indexable)
        group = try container.decodeIfPresent(Bool.self, forKey: .group)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        avatar_static = try container.decodeIfPresent(String.self, forKey: .avatar_static)
        header = try container.decodeIfPresent(String.self, forKey: .header)
        header_static = try container.decodeIfPresent(String.self, forKey: .header_static)
        followers_count = try container.decodeIfPresent(Int.self, forKey: .followers_count)
        following_count = try container.decodeIfPresent(Int.self, forKey: .following_count)
        statuses_count = try container.decodeIfPresent(Int.self, forKey: .statuses_count)
        last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at)
        suspended = try container.decodeIfPresent(Bool.self, forKey: .suspended)
        hide_collections = try container.decodeIfPresent(Bool.self, forKey: .hide_collections)
        noindex = try container.decodeIfPresent(Bool.self, forKey: .noindex)
        source = try container.decodeIfPresent(Source.self, forKey: .source)
        emojis = try container.decodeIfPresent([Emoji].self, forKey: .emojis)
        roles = try container.decodeIfPresent([Role].self, forKey: .roles)
        fields = try container.decodeIfPresent([Field].self, forKey: .fields)

        //Important: Use decodeIfPresent and provide a default value. - Keep as it is
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at)
    }

    // MARK: - Encoder - Keep encoder as is, handling optional created_at encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(acct, forKey: .acct)
        try container.encode(display_name, forKey: .display_name)
        try container.encodeIfPresent(locked, forKey: .locked)
        try container.encodeIfPresent(bot, forKey: .bot)
        try container.encodeIfPresent(discoverable, forKey: .discoverable)
        try container.encodeIfPresent(indexable, forKey: .indexable)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(avatar_static, forKey: .avatar_static)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(header_static, forKey: .header_static)
        try container.encodeIfPresent(followers_count, forKey: .followers_count)
        try container.encodeIfPresent(following_count, forKey: .following_count)
        try container.encodeIfPresent(statuses_count, forKey: .statuses_count)
        try container.encodeIfPresent(last_status_at, forKey: .last_status_at)
        try container.encodeIfPresent(suspended, forKey: .suspended)
        try container.encodeIfPresent(hide_collections, forKey: .hide_collections)
        try container.encodeIfPresent(noindex, forKey: .noindex)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(emojis, forKey: .emojis)
        try container.encodeIfPresent(roles, forKey: .roles)
        try container.encodeIfPresent(fields, forKey: .fields)

        if let created_at = created_at { // Only encode if not nil
            try container.encode(created_at, forKey: .created_at)
        }
    }

    // MARK: - Hashable Conformance (No change)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Equatable Conformance (No change)
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id // Simplified equality check
    }

    // MARK: - Default User (Fallback)
    static var `default`: User {
        return User(
            id: "unknown",
            username: "unknown_user",
            acct: "unknown",
            display_name: "Unknown User",
            locked: false,
            bot: false,
            discoverable: false,
            indexable: false,
            group: false,
            created_at: nil,
            note: nil,
            url: nil,
            avatar: nil,
            avatar_static: nil,
            header: nil,
            header_static: nil,
            followers_count: 0,
            following_count: 0,
            statuses_count: 0,
            last_status_at: nil,
            suspended: false,
            hide_collections: false,
            noindex: false,
            source: nil,
            emojis: [],
            roles: [],
            fields: []
        )
    }
}

