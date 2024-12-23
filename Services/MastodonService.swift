//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftUI

/// Service responsible for interacting with the Mastodon API.
@MainActor
class MastodonService: MastodonServiceProtocol, ObservableObject {
    /// Optional shared instance if your code/tests references it
    static let shared = MastodonService()

    /// The base URL of the Mastodon instance.
    var baseURL: URL?

    /// Securely read an access token from the keychain
    private var accessToken: String? {
        guard let baseURL = baseURL else { return nil }
        let service = "Mustard-\(baseURL.host ?? "")"
        return KeychainHelper.shared.read(service: service, account: "accessToken")
    }

    /// Helper to create an authorized URLRequest (if `baseURL` & `accessToken` are available).
    private func createRequest(endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let baseURL = baseURL else { return nil }
        let apiVersion = "v1"
        let url = baseURL.appendingPathComponent("api/\(apiVersion)/\(endpoint)")
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // If we have a token, attach it
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            // Content-Type can differ based on endpoint
            if endpoint == "statuses" {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            } else {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }
    
    // MARK: - Public API
    
    func fetchHomeTimeline() async throws -> [Post] {
        guard let request = createRequest(endpoint: "timelines/home") else {
            throw MustardAppError(message: "Instance URL not set.")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        // Decode array of MastodonPostData
        let postsData: [MastodonPostData] = try JSONDecoder().decode([MastodonPostData].self, from: data)
        return postsData.map { $0.toPost() }
    }
    
    func fetchPosts(keyword: String) async throws -> [Post] {
        let endpoint = "timelines/tag/\(keyword)"
        guard let request = createRequest(endpoint: endpoint) else {
            throw MustardAppError(message: "Instance URL not set.")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postsData: [MastodonPostData] = try JSONDecoder().decode([MastodonPostData].self, from: data)
        return postsData.map { $0.toPost() }
    }
    
    func likePost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/favourite"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    func unlikePost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/unfavourite"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    func repost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/reblog"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    func undoRepost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/unreblog"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    func comment(postID: String, content: String) async throws -> Post {
        let endpoint = "statuses"
        let parameters: [String: String] = [
            "status": content,
            "in_reply_to_id": postID
        ]
        guard let bodyData = parameters.percentEncoded(),
              let request = createRequest(endpoint: endpoint, method: "POST", body: bodyData)
        else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    // MARK: - Internal Helpers
    
    private func performPostAction(request: URLRequest) async throws -> Post {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postData = try JSONDecoder().decode(MastodonPostData.self, from: data)
        return postData.toPost()
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MustardAppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MustardAppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
}

// MARK: - JSON Decoding Structs
//   Ensure these do NOT appear in multiple files, or you'll get "invalid redeclaration" errors.

/// Data structure used for decoding a single Mastodon post from JSON.
struct MastodonPostData: Decodable {
    let id: String
    let content: String
    let created_at: String
    let account: MastodonAccountData
    let media_attachments: [MastodonMediaAttachmentData]
    let favourited: Bool?
    let reblogged: Bool?
    let reblogs_count: Int
    let favourites_count: Int
    let replies_count: Int

    func toPost() -> Post {
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: created_at) ?? Date()

        return Post(
            id: id,
            content: content,
            createdAt: createdDate,
            account: account.toAccount(),
            mediaAttachments: media_attachments.map { $0.toMediaAttachment() },
            isFavourited: favourited ?? false,
            isReblogged: reblogged ?? false,
            reblogsCount: reblogs_count,
            favouritesCount: favourites_count,
            repliesCount: replies_count
        )
    }
}

struct MastodonAccountData: Decodable {
    let id: String
    let username: String
    let display_name: String
    let avatar: String
    let acct: String
    
    func toAccount() -> Account {
        // Convert the avatar URL string to a URL
        let avatarURL = URL(string: avatar) ?? URL(string: "https://example.com")!
        return Account(
            id: id,
            username: username,
            displayName: display_name,
            avatar: avatarURL,
            acct: acct
        )
    }
}

struct MastodonMediaAttachmentData: Decodable {
    let id: String
    let type: String
    let url: String
    let preview_url: String?
    
    func toMediaAttachment() -> MediaAttachment {
        MediaAttachment(
            id: id,
            type: type,
            url: URL(string: url) ?? URL(string: "https://example.com")!,
            previewUrl: preview_url != nil ? URL(string: preview_url!) : nil
        )
    }
}

// MARK: - Dictionary helper for URL-encoding
extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

