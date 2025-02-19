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
// Removed @MainActor because it's not necessary for this struct

struct RegisterResponse: Decodable {
    let id: String
    let name: String
    let website: String?
    let vapidKey: String // Mastodon returns `vapid_key` -> vapidKey
    let clientId: String // Mastodon returns `client_id` -> clientId
    let clientSecret: String // Mastodon returns `client_secret` -> clientSecret
    let redirectUri: String // Mastodon returns `redirect_uri` -> redirectUri
    
    // If Mastodon includes extra fields like `scopes`, `redirect_uris`, etc.
    // .convertFromSnakeCase will decode them if you list them here in camelCase, e.g.:
    // let scopes: [String]?   // Mastodon might return `scopes:["read","write","follow","push"]`
    // let redirectUris: [String]? // `redirect_uris`
}

// MARK: - TokenResponse
struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let createdAt: String?
    let expiresIn: Int? // Add this back, but make it optional
    
    // Removed expiresIn as per recommendations for targeted decoding and if not essential for your app.
    // If you need expiresIn, keep it and consider making it optional if the API is inconsistent.
    // let expiresIn: Int?
    
    // Removed CodingKeys as per recommendations to use .convertFromSnakeCase
    // in JSONDecoder and property names match camelCase versions of API keys.
    // If you still face issues, reinstate CodingKeys and adjust mappings as needed.
    // enum CodingKeys: String, CodingKey {
    //  case accessToken = "access_token"
    //  case tokenType = "token_type"
    //  case scope
    //  case createdAt = "created_at"
    //  case expiresIn = "expires_in"
    // }
}

// MARK: - WeatherData

struct WeatherData: Decodable {
    let temperature: Double
    let description: String
    let cityName: String
}

struct OpenWeatherResponse: Decodable {
    struct Main: Decodable {
        let temp: Double
        let feels_like: Double
        let temp_min: Double
        let temp_max: Double
        let pressure: Int
        let humidity: Int
        let sea_level: Int?
        let grnd_level: Int?
    }
    
    struct Weather: Decodable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }
    
    struct Wind: Decodable {
        let speed: Double
        let deg: Int
        let gust: Double? //gust is optional
    }
    
    struct Clouds: Decodable {
        let all: Int
    }
    struct Sys: Decodable {
        let type: Int?
        let id: Int?
        let country: String
        let sunrise: Int
        let sunset: Int
    }
    let coord: Coordinates
    let weather: [Weather]
    let base: String
    let main: Main
    let visibility: Int
    let wind: Wind
    let clouds: Clouds
    let dt: Int
    let sys: Sys
    let timezone: Int
    let id: Int
    let name: String
    let cod: Int
    
    struct Coordinates: Decodable {
        let lon: Double
        let lat: Double
    }
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
    var url: URL? // Make URL optional
    var history: [History]? // Keep this as it's part of the response

    // No 'id' property is needed here. 'name' is sufficient.

    init(name: String, url: URL?, history: [History]? = nil) {
        self.name = name
        self.url = url
        self.history = history
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, url, history
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        // Handle URL as a String and convert to URL
        let urlString = try container.decode(String.self, forKey: .url)
        url = URL(string: urlString) // Convert String to URL, handling potential failure

        history = try container.decodeIfPresent([History].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url) // Encode as String
        try container.encodeIfPresent(history, forKey: .history)
    }
}

// History struct remains the same (it's decoding correctly)
struct History: Codable {
    let day: String
    let accounts: String // API returns counts as strings
    let uses: String

    // Custom initializer for converting strings to Ints if needed
    init(day: String, accounts: String, uses: String) {
        self.day = day
        self.accounts = accounts
        self.uses = uses
    }

    //Codable
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
/// Represents a small subset of instance info returned by the Mastodon server.
struct InstanceInfo: Decodable {
    let title: String
    let description: String
    let thumbnail: URL?
    
    enum CodingKeys: String, CodingKey {
        case title, description, thumbnail
    }
}
