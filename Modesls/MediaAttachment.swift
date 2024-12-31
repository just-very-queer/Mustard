//
//  MediaAttachment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

/// Represents a media attachment in a Mastodon post.
@Model
final class MediaAttachment: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var type: MediaType
    var url: URL

    // MARK: - Media Types
    enum MediaType: String, Codable {
        case image
        case video
        case unknown
    }

    // MARK: - Initializer
    init(id: String, type: MediaType, url: URL) {
        self.id = id
        self.type = type
        self.url = url
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id, type, url
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(MediaType.self, forKey: .type)
        self.url = try container.decode(URL.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(url, forKey: .url)
    }
}

