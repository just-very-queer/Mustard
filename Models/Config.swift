//
//  Config.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation

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
    let vapidKey: String      // Mastodon returns `vapid_key` -> vapidKey
    let clientId: String      // Mastodon returns `client_id` -> clientId
    let clientSecret: String  // Mastodon returns `client_secret` -> clientSecret
    let redirectUri: String   // Mastodon returns `redirect_uri` -> redirectUri

    // If Mastodon includes extra fields like `scopes`, `redirect_uris`, etc.
    // .convertFromSnakeCase will decode them if you list them here in camelCase, e.g.:
    // let scopes: [String]?   // Mastodon might return `scopes:["read","write","follow","push"]`
    // let redirectUris: [String]? // `redirect_uris`
}

//struct RegisterResponse: Decodable {
//    let id: String
//    let name: String
//    let website: String?
//    let vapidKey: String
//    let clientId: String
//    let clientSecret: String
//    let redirectUri: String
//    
//    /// Stores any extra fields in the JSON that are not part of the known CodingKeys.
//    private(set) var unknownKeys: [String: Any]? = nil
//    
//    enum CodingKeys: String, CodingKey {
//        case id, name, website
//        case vapidKey = "vapid_key"
//        case clientId = "client_id"
//        case clientSecret = "client_secret"
//        case redirectUri = "redirect_uri"
//    }
//    
//    init(from decoder: Decoder) throws {
//        // Decode known fields
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decode(String.self, forKey: .id)
//        name = try container.decode(String.self, forKey: .name)
//        website = try container.decodeIfPresent(String.self, forKey: .website)
//        vapidKey = try container.decode(String.self, forKey: .vapidKey)
//        clientId = try container.decode(String.self, forKey: .clientId)
//        clientSecret = try container.decode(String.self, forKey: .clientSecret)
//        redirectUri = try container.decode(String.self, forKey: .redirectUri)
//        
//        // Decode all other keys into unknownKeys
//        let allKeysContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
//        var additionalData = [String: Any]()
//        
//        for key in allKeysContainer.allKeys {
//            // Skip the keys we already know about
//            guard CodingKeys(stringValue: key.stringValue) == nil else { continue }
//            
//            // Try various decodes
//            if let stringValue = try? allKeysContainer.decode(String.self, forKey: key) {
//                additionalData[key.stringValue] = stringValue
//                continue
//            }
//            if let intValue = try? allKeysContainer.decode(Int.self, forKey: key) {
//                additionalData[key.stringValue] = intValue
//                continue
//            }
//            if let boolValue = try? allKeysContainer.decode(Bool.self, forKey: key) {
//                additionalData[key.stringValue] = boolValue
//                continue
//            }
//            if let doubleValue = try? allKeysContainer.decode(Double.self, forKey: key) {
//                additionalData[key.stringValue] = doubleValue
//                continue
//            }
//            if let stringArray = try? allKeysContainer.decode([String].self, forKey: key) {
//                additionalData[key.stringValue] = stringArray
//                continue
//            }
//            
//            // If needed, you could handle more types or store raw JSON data here.
//            // For example:
//            // let rawData = try allKeysContainer.decodeRawData(forKey: key)
//            // additionalData[key.stringValue] = rawData
//            
//            // Otherwise, just skip it if we cannot decode a known type
//        }
//        
//        // Assign only if we actually found unknown fields
//        unknownKeys = additionalData.isEmpty ? nil : additionalData
//    }
//
//    // Helper struct to decode any key
//    private struct DynamicCodingKeys: CodingKey {
//        var stringValue: String
//        var intValue: Int?
//        
//        init?(stringValue: String) {
//            self.stringValue = stringValue
//            self.intValue = nil
//        }
//        
//        init?(intValue: Int) {
//            self.stringValue = "\(intValue)"
//            self.intValue = intValue
//        }
//    }
//}


// MARK: - TokenResponse
struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case createdAt = "created_at"
    }
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
