//
// Config.swift
// Mustard
//
// Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import SwiftData

// MARK: - OAuth Config
struct OAuthConfig: Decodable, Sendable {
    let clientId: String
    let clientSecret: String
    let redirectUri: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectUri = "redirect_uri"
        case scope
    }
}

// MARK: - RegisterResponse Struct
struct RegisterResponse: Decodable {
    let id: String
    let name: String
    let website: String?
    let vapidKey: String
    let clientId: String
    let clientSecret: String
    let redirectUri: String

    // Note: keyDecodingStrategy = .convertFromSnakeCase in NetworkSessionManager
    // will handle mapping snake_case keys from JSON to camelCase properties.
}

// MARK: - TokenResponse
struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let createdAt: Int? // FIX: Changed from String? to Int? for UNIX timestamp
    let expiresIn: Int?

    // No explicit CodingKeys needed if NetworkSessionManager.jsonDecoder
    // uses .keyDecodingStrategy = .convertFromSnakeCase
    // and property names match (e.g., accessToken for access_token).
}

// MARK: - Cached

/// Cached timeline with posts and timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

// MARK: - Application
struct Application: Codable, Equatable {
    let name: String
    let website: URL?
}

// MARK: - Mention
struct Mention: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let url: URL
    let acct: String
}

// MARK: - Tag
@Model
class Tag: Codable, Identifiable {
    var name: String
    var url: URL?
    var history: [History]?

    init(name: String, url: URL?, history: [History]? = nil) {
        self.name = name
        self.url = url
        self.history = history
    }

    enum CodingKeys: String, CodingKey {
        case name, url, history
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .url) {
            url = URL(string: urlString)
        } else {
            url = nil
        }
        history = try container.decodeIfPresent([History].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)
        try container.encodeIfPresent(history, forKey: .history)
    }
}

struct History: Codable {
    let day: String
    let accounts: String
    let uses: String

    init(day: String, accounts: String, uses: String) {
        self.day = day
        self.accounts = accounts
        self.uses = uses
    }

    enum CodingKeys: String, CodingKey{
        case day, accounts, uses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        accounts = try container.decode(String.self, forKey: .accounts)
        uses = try container.decode(String.self, forKey: .uses)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(uses, forKey: .uses)
    }
}

// MARK: - Minimal Model for /api/v1/instance
struct InstanceInfo: Decodable {
    let title: String
    let description: String // This 'description' is not for a @Model, so it's fine.
    let thumbnail: URL?

    enum CodingKeys: String, CodingKey {
        case title, description, thumbnail
    }
}
