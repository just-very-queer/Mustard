//
//  MediaAttachment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

/// Represents a media attachment in a Mastodon post.
@Model
final class MediaAttachment: Identifiable, Codable, Equatable {
 @Attribute(.unique) var id: String
 var type: MediaType
 var url: URL? // Making URL optional for robustness
 var previewURL: URL?
 var remoteURL: URL?
 var meta: Meta?

 // MARK: - Media Types
 enum MediaType: String, Codable, Equatable {
  case image
  case video
  case gifv // Add this case
  case unknown
 }

 // MARK: - Meta Data
 struct Meta: Codable, Equatable {
  var original: Original?

  struct Original: Codable, Equatable {
   var width: Int?
   var height: Int?
   var size: String?
  }
 }

 // MARK: - Initializer
 init(
  id: String,
  type: MediaType,
  url: URL?, // Making URL optional in initializer
  previewURL: URL? = nil,
  remoteURL: URL? = nil,
  meta: Meta? = nil
 ) {
  self.id = id
  self.type = type
  self.url = url
  self.previewURL = previewURL
  self.remoteURL = remoteURL
  self.meta = meta
 }

 // MARK: - Codable Conformance
 private enum CodingKeys: String, CodingKey {
  case id, type, url, previewURL, remoteURL, meta
 }

 required init(from decoder: Decoder) throws {
  let container = try decoder.container(keyedBy: CodingKeys.self)
  self.id = try container.decode(String.self, forKey: .id)
  self.type = try container.decode(MediaType.self, forKey: .type)
  self.url = try container.decodeIfPresent(URL.self, forKey: .url) // Decoding URL as optional
  self.previewURL = try container.decodeIfPresent(URL.self, forKey: .previewURL)
  self.remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
  self.meta = try container.decodeIfPresent(Meta.self, forKey: .meta)
 }

 func encode(to encoder: Encoder) throws {
  var container = encoder.container(keyedBy: CodingKeys.self)
  try container.encode(id, forKey: .id)
  try container.encode(type, forKey: .type)
  try container.encodeIfPresent(url, forKey: .url) // Encoding optional URL
  try container.encodeIfPresent(previewURL, forKey: .previewURL)
  try container.encodeIfPresent(remoteURL, forKey: .remoteURL)
  try container.encodeIfPresent(meta, forKey: .meta)
 }
    
 // MARK: - Equatable Conformance
 static func == (lhs: MediaAttachment, rhs: MediaAttachment) -> Bool {
  return lhs.id == rhs.id &&
     lhs.type == rhs.type &&
     lhs.url == rhs.url &&
     lhs.previewURL == rhs.previewURL &&
     lhs.remoteURL == rhs.remoteURL &&
     lhs.meta == rhs.meta
 }
}
