//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

@Model
final class Account: Identifiable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var username: String
    var display_name: String? // Nullable `display_name` from API
    var avatar: URL
    var acct: String
    var url: URL // Profile URL
    var accessToken: String? = nil
    var followers_count: Int? // Number of followers
    var following_count: Int? // Number of following
    var statuses_count: Int? // Number of posts/statuses
    var last_status_at: String? // Last status date as a string
    var isBot: Bool? // Indicates if the account is a bot
    var isLocked: Bool? // Indicates if the account is locked
    var note: String? // Bio or note
    var header: URL? // Profile header image
    var header_static: URL? // Static version of the header image

    // Computed property to derive instance URL from the profile URL
    var instanceURL: URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }

    // MARK: - Initializer
    init(
        id: String,
        username: String,
        display_name: String?,
        avatar: URL,
        acct: String,
        url: URL,
        accessToken: String? = nil,
        followers_count: Int? = nil,
        following_count: Int? = nil,
        statuses_count: Int? = nil,
        last_status_at: String? = nil,
        isBot: Bool? = nil,
        isLocked: Bool? = nil,
        note: String? = nil,
        header: URL? = nil,
        header_static: URL? = nil
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
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, username, acct, avatar, url, accessToken, note, header, header_static
        case display_name = "display_name"
        case followers_count = "followers_count"
        case following_count = "following_count"
        case statuses_count = "statuses_count"
        case last_status_at = "last_status_at"
        case isBot = "bot"
        case isLocked = "locked"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        self.display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        self.avatar = try container.decode(URL.self, forKey: .avatar)
        self.acct = try container.decode(String.self, forKey: .acct)
        self.url = try container.decode(URL.self, forKey: .url)
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        self.followers_count = try container.decodeIfPresent(Int.self, forKey: .followers_count)
        self.following_count = try container.decodeIfPresent(Int.self, forKey: .following_count)
        self.statuses_count = try container.decodeIfPresent(Int.self, forKey: .statuses_count)
        self.last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at)
        self.isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot)
        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.header = try container.decodeIfPresent(URL.self, forKey: .header)
        self.header_static = try container.decodeIfPresent(URL.self, forKey: .header_static)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(display_name, forKey: .display_name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(acct, forKey: .acct)
        try container.encode(url, forKey: .url)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(followers_count, forKey: .followers_count)
        try container.encodeIfPresent(following_count, forKey: .following_count)
        try container.encodeIfPresent(statuses_count, forKey: .statuses_count)
        try container.encodeIfPresent(last_status_at, forKey: .last_status_at)
        try container.encodeIfPresent(isBot, forKey: .isBot)
        try container.encodeIfPresent(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(header_static, forKey: .header_static)
    }

    // MARK: - Equatable Conformance
    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id &&
            lhs.username == rhs.username &&
            lhs.display_name == rhs.display_name &&
            lhs.avatar == rhs.avatar &&
            lhs.acct == rhs.acct &&
            lhs.url == rhs.url &&
            lhs.accessToken == rhs.accessToken &&
            lhs.followers_count == rhs.followers_count &&
            lhs.following_count == rhs.following_count &&
            lhs.statuses_count == rhs.statuses_count &&
            lhs.last_status_at == rhs.last_status_at &&
            lhs.isBot == rhs.isBot &&
            lhs.isLocked == rhs.isLocked &&
            lhs.note == rhs.note &&
            lhs.header == rhs.header &&
            lhs.header_static == rhs.header_static
    }
}

