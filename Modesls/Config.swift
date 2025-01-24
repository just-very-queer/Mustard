//
//  Config.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation

@MainActor
//OAuth Config
struct OAuthConfig: Sendable {
    let clientId: String
    let clientSecret: String
    let redirectUri: String // Updated name to match usage
    let scope: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectUri = "redirect_uri" // Updated name to match usage
        case scope
    }
}

// RegisterResponse Struct (Updated to match the correct names)
@MainActor
struct RegisterResponse: Codable, Sendable {
    let id: String?
    let name: String?
    let website: String?
    let vapidKey: String
    let clientId: String // Correctly mapped from "client_id"
    let clientSecret: String // Correctly mapped from "client_secret"
    let redirectUri: String? // Correctly mapped from "redirect_uri"

    enum CodingKeys: String, CodingKey {
        case id, name, website
        case vapidKey = "vapid_key"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case redirectUri = "redirect_uri"
    }
}


/// Represents the response received after obtaining an access token.
struct TokenResponse: Codable, Sendable {
    let access_token: String
    let token_type: String
    let scope: String
    let created_at: Int
    
    /// Convenience property to access `access_token`.
    var accessToken: String { access_token }
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
struct Tag: Codable, Equatable {
    let name: String
    let url: URL
}
