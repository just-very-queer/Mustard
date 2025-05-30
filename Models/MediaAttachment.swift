//
//  MediaAttachment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

@Model
final class MediaAttachment: Identifiable, Codable, Equatable {
    @Attribute(.unique) var id: String
    var type: MediaType
    var url: URL?
    var previewURL: URL?
    var remoteURL: URL?
    var meta: Meta?

    // Inverse relationship: A MediaAttachment belongs to one Post.
    // Post.mediaAttachments is the 'to-many' side. This is the 'to-one' side.
    // Per Apple's pattern, the to-one side usually doesn't specify the inverse if the to-many side does.
    var post: Post?

    // MARK: - Media Types
    enum MediaType: String, Codable, Equatable {
        case image, video, gifv, unknown
    }

    // MARK: - Meta Data (ensure it's Codable and Equatable)
    struct Meta: Codable, Equatable {
        var original: Original?
        struct Original: Codable, Equatable {
            var width: Int?
            var height: Int?
            var size: String?
        }
    }

    // MARK: - Initializer
    init(id: String, type: MediaType, url: URL?, previewURL: URL? = nil, remoteURL: URL? = nil, meta: Meta? = nil, post: Post? = nil) { // Added post
        self.id = id
        self.type = type
        self.url = url
        self.previewURL = previewURL
        self.remoteURL = remoteURL
        self.meta = meta
        self.post = post // Initialize post
    }

    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        // 'post' is a relationship, not typically in MediaAttachment JSON
        case id, type, url, previewURL, remoteURL, meta
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(MediaType.self, forKey: .type)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
        remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
        meta = try container.decodeIfPresent(Meta.self, forKey: .meta)
        // 'post' is not decoded from JSON here
        post = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        // ... encode other properties ...
        // Do not encode 'post'
    }
    
    static func == (lhs: MediaAttachment, rhs: MediaAttachment) -> Bool {
        lhs.id == rhs.id
    }
}
