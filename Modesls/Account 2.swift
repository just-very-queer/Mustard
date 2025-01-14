//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

/// Represents a Mastodon account.
@Model
final class Account: Identifiable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var username: String
    var displayName: String
    var avatar: URL
    var acct: String
    var instanceURL: URL
    var accessToken: String?

    // MARK: - Initializer
    init(
        id: String,
        username: String,
        displayName: String,
        avatar: URL,
        acct: String,
        instanceURL: URL,
        accessToken: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatar = avatar
        self.acct = acct
        self.instanceURL = instanceURL
        self.accessToken = accessToken
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, username, displayName, avatar, acct, instanceURL, accessToken
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.avatar = try container.decode(URL.self, forKey: .avatar)
        self.acct = try container.decode(String.self, forKey: .acct)
        self.instanceURL = try container.decode(URL.self, forKey: .instanceURL)
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(acct, forKey: .acct)
        try container.encode(instanceURL, forKey: .instanceURL)
        try container.encode(accessToken, forKey: .accessToken)
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id &&
               lhs.username == rhs.username &&
               lhs.displayName == rhs.displayName &&
               lhs.avatar == rhs.avatar &&
               lhs.acct == rhs.acct &&
               lhs.instanceURL == rhs.instanceURL &&
               lhs.accessToken == rhs.accessToken
    }
}
