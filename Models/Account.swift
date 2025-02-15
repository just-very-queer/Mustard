//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftData

@Model
class Account: Identifiable, Codable, Equatable {
 @Attribute(.unique) var id: String
 var username: String
 var display_name: String?
 var avatar: URL? // Make avatar URL optional to align with potential API responses and User.swift
 var acct: String
 var url: URL? // Make url optional to align with potential API responses and User.swift
 var accessToken: String? = nil
 var followers_count: Int? // Corrected to snake_case to match API and align with CodingKeys
 var following_count: Int? // Corrected to snake_case to match API and align with CodingKeys
 var statuses_count: Int? // Corrected to snake_case to match API and align with CodingKeys
 var last_status_at: String? // Corrected to snake_case to match API and align with CodingKeys
 var isBot: Bool? // Corrected to isBot to align with CodingKeys and camelCase convention
 var isLocked: Bool? // Corrected to isLocked to align with CodingKeys and camelCase convention
 var note: String?
 var header: URL?
 var header_static: URL? // Corrected to snake_case to match API and align with CodingKey
 // Added properties to match User model
 var discoverable: Bool?
 var indexable: Bool?
 var suspended: Bool?

 // Computed property to derive instance URL from the profile URL
 var instanceURL: URL? {
  guard let url = url, let host = url.host else { return nil } // Safe unwrap optional url
  return URL(string: "https://\(host)")
 }

 // MARK: - Initializer
 init(
  id: String,
  username: String,
  display_name: String?,
  avatar: URL?, // Make avatar URL optional in initializer
  acct: String,
  url: URL?, // Make url optional in initializer
  accessToken: String? = nil,
  followers_count: Int? = nil, // Corrected to snake_case to match property
  following_count: Int? = nil, // Corrected to snake_case to match property
  statuses_count: Int? = nil, // Corrected to snake_case to match property
  last_status_at: String? = nil, // Corrected to snake_case to match property
  isBot: Bool? = nil, // Corrected to isBot to match property
  isLocked: Bool? = nil, // Corrected to isLocked to match property
  note: String? = nil,
  header: URL? = nil,
  header_static: URL? = nil, // Corrected to snake_case to match property
  discoverable: Bool? = nil,
  indexable: Bool? = nil,
  suspended: Bool? = nil
 ) {
  self.id = id
  self.username = username
  self.display_name = display_name
  self.avatar = avatar
  self.acct = acct
  self.url = url
  self.accessToken = accessToken
  self.followers_count = followers_count // Corrected to snake_case to match property
  self.following_count = following_count // Corrected to snake_case to match property
  self.statuses_count = statuses_count // Corrected to snake_case to match property
  self.last_status_at = last_status_at // Corrected to snake_case to match property
  self.isBot = isBot // Corrected to isBot to match property
  self.isLocked = isLocked // Corrected to isLocked to match property
  self.note = note
  self.header = header
  self.header_static = header_static // Corrected to snake_case to match property
  self.discoverable = discoverable
  self.indexable = indexable
  self.suspended = suspended
 }

 // MARK: - Codable Conformance
 private enum CodingKeys: String, CodingKey {
  case id, username, acct, avatar, url, accessToken, note, header, discoverable, indexable, suspended
  case display_name = "display_name"
  case followers_count = "followers_count" // Corrected to snake_case
  case following_count = "following_count" // Corrected to snake_case
  case statuses_count = "statuses_count" // Corrected to snake_case
  case last_status_at = "last_status_at" // Corrected to snake_case
  case isBot = "bot" // Corrected to isBot to match property
  case isLocked = "locked" // Corrected to isLocked to match property
  case header_static = "header_static" // Corrected to snake_case
 }

 required init(from decoder: Decoder) throws {
  let container = try decoder.container(keyedBy: CodingKeys.self)
  self.id = try container.decode(String.self, forKey: .id)
  self.username = try container.decode(String.self, forKey: .username)
  self.display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
  self.avatar = try container.decodeIfPresent(URL.self, forKey: .avatar) // Decode as optional
  self.acct = try container.decode(String.self, forKey: .acct)
  self.url = try container.decodeIfPresent(URL.self, forKey: .url) // Decode as optional
  self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
  self.followers_count = try container.decodeIfPresent(Int.self, forKey: .followers_count) // Corrected to snake_case
  self.following_count = try container.decodeIfPresent(Int.self, forKey: .following_count) // Corrected to snake_case
  self.statuses_count = try container.decodeIfPresent(Int.self, forKey: .statuses_count) // Corrected to snake_case
  self.last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at) // Corrected to snake_case
  self.isBot = try container.decodeIfPresent(Bool.self, forKey: .isBot) // Corrected to isBot
  self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) // Corrected to isLocked
  self.note = try container.decodeIfPresent(String.self, forKey: .note)
  self.header = try container.decodeIfPresent(URL.self, forKey: .header)
  self.header_static = try container.decodeIfPresent(URL.self, forKey: .header_static) // Corrected to snake_case
  self.discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
  self.indexable = try container.decodeIfPresent(Bool.self, forKey: .indexable)
  self.suspended = try container.decodeIfPresent(Bool.self, forKey: .suspended)
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
  try container.encodeIfPresent(followers_count, forKey: .followers_count) // Corrected to snake_case
  try container.encodeIfPresent(following_count, forKey: .following_count) // Corrected to snake_case
  try container.encodeIfPresent(statuses_count, forKey: .statuses_count) // Corrected to snake_case
  try container.encodeIfPresent(last_status_at, forKey: .last_status_at) // Corrected to snake_case
  try container.encodeIfPresent(isBot, forKey: .isBot) // Corrected to isBot
  try container.encodeIfPresent(isLocked, forKey: .isLocked) // Corrected to isLocked
  try container.encodeIfPresent(note, forKey: .note)
  try container.encodeIfPresent(header, forKey: .header)
  try container.encodeIfPresent(header_static, forKey: .header_static) // Corrected to snake_case
  try container.encodeIfPresent(discoverable, forKey: .discoverable)
  try container.encodeIfPresent(indexable, forKey: .indexable)
  try container.encodeIfPresent(suspended, forKey: .suspended)
 }

 // MARK: - Equatable Conformance
 static func == (lhs: Account, rhs: Account) -> Bool {
  lhs.id == rhs.id
 }
}
