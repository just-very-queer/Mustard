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
final class MediaAttachment: Identifiable {
    @Attribute(.unique) var id: String
    var type: MediaType
    var url: URL
    var previewUrl: URL?

    // MARK: - Media Types
    enum MediaType: String, Codable {
        case image
        case video
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let typeString = try container.decode(String.self).lowercased()
            self = MediaType(rawValue: typeString) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    // MARK: - Initializers

    /// Initializes a MediaAttachment with all properties.
    /// - Parameters:
    ///   - id: The unique identifier for the media attachment.
    ///   - type: The type of media (image, video, or unknown).
    ///   - url: The URL of the media.
    ///   - previewUrl: An optional URL for a preview of the media.
    init(id: String, type: MediaType, url: URL, previewUrl: URL? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.previewUrl = previewUrl
    }
}

