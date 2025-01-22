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
    var display_name: String
    var avatar: URL
    var acct: String
    var url: URL // Changed from 'instanceURL'
    var accessToken: String? = nil
    // Computed property to derive instanceURL from the profile URL
    var instanceURL: URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }

    // MARK: - Initializer
    init(
        id: String,
        username: String,
        displayName: String,
        avatar: URL,
        acct: String,
        url: URL, // Changed from instanceURL
        accessToken: String? = nil
    ) {
        self.id = id
        self.username = username
        self.display_name = displayName
        self.avatar = avatar
        self.acct = acct
        self.url = url // Changed from instanceURL
        self.accessToken = accessToken
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, username, avatar, acct, url, accessToken
        case display_name = "display_name"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.username = try container.decode(String.self, forKey: .username)
        self.display_name = try container.decode(String.self, forKey: .display_name)
        self.avatar = try container.decode(URL.self, forKey: .avatar)
        self.acct = try container.decode(String.self, forKey: .acct)
        self.url = try container.decode(URL.self, forKey: .url)
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
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
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id == rhs.id &&
            lhs.username == rhs.username &&
            lhs.display_name == rhs.display_name &&
            lhs.avatar == rhs.avatar &&
            lhs.acct == rhs.acct &&
            lhs.url == rhs.url &&
            lhs.accessToken == rhs.accessToken
    }
}
