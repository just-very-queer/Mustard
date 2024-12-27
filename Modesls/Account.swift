//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

/// Represents a Mastodon account.
@Model
class Account: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var username: String
    var displayName: String
    var avatar: URL
    var acct: String
    var instanceURL: URL?
    var accessToken: String?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatar
        case acct
        case instanceURL = "instance_url"
        case accessToken = "access_token"
    }
    
    // MARK: - Initializers
    
    /// Decoding initializer (for when reading from JSON).
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.avatar = try container.decode(URL.self, forKey: .avatar)
        self.acct = try container.decode(String.self, forKey: .acct)
        self.instanceURL = try container.decodeIfPresent(URL.self, forKey: .instanceURL)
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
    }
    
    /// Encoding method (for when writing to JSON).
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
    
    /// Normal initializer (for constructing in code).
    init(id: String,
         username: String,
         displayName: String,
         avatar: URL,
         acct: String,
         instanceURL: URL?,
         accessToken: String?) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatar = avatar
        self.acct = acct
        self.instanceURL = instanceURL
        self.accessToken = accessToken
    }
}
