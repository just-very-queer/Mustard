//
//  MediaAttachment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

/// Represents a media attachment in a Mastodon post.
@Model
final class MediaAttachment: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var type: MediaType
    var url: URL
    var previewUrl: URL?

    // MARK: - Media Types
    enum MediaType: String, Codable {
        case image
        case video
        case unknown
    }

    // MARK: - Initializer (for SwiftData usage)
    
    init(id: String,
         type: MediaType,
         url: URL,
         previewUrl: URL? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.previewUrl = previewUrl
    }
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case previewUrl
    }
    
    // MARK: - Decodable
    
    /// Manual initializer for decoding a `MediaAttachment` from JSON.
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(MediaType.self, forKey: .type)
        self.url = try container.decode(URL.self, forKey: .url)
        self.previewUrl = try container.decodeIfPresent(URL.self, forKey: .previewUrl)
    }
    
    // MARK: - Encodable
    
    /// Manual method for encoding `MediaAttachment` to JSON.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encode(previewUrl, forKey: .previewUrl)
    }
}

