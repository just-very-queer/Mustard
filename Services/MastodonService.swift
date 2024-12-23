//
//  MastodonService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Service responsible for interacting with the Mastodon API.
@MainActor
class MastodonService: MastodonServiceProtocol {
    /// Shared singleton instance, typed as the protocol for flexibility.
    static var shared: MastodonServiceProtocol = MastodonService()
    
    /// Base URL of the Mastodon instance.
    var baseURL: URL?
    
    /// Access token for authentication, securely stored in the keychain.
    private var accessToken: String? {
        guard let baseURL = baseURL else { return nil }
        let service = "Mustard-\(baseURL.host ?? "")"
        return KeychainHelper.shared.read(service: service, account: "accessToken")
    }
    
    /// Creates a URLRequest with the given endpoint, method, and body.
    /// - Parameters:
    ///   - endpoint: API endpoint (e.g., "timelines/home").
    ///   - method: HTTP method (default is "GET").
    ///   - body: Optional HTTP body data.
    /// - Returns: Configured URLRequest or nil if baseURL is not set.
    private func createRequest(endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard let baseURL = baseURL else { return nil }
        let url = baseURL.appendingPathComponent("api/v1/\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
    
    /// Fetches the home timeline posts.
    /// - Returns: Array of `Post` objects.
    func fetchHomeTimeline() async throws -> [Post] {
        guard let request = createRequest(endpoint: "timelines/home") else {
            throw MustardAppError(message: "Instance URL not set.")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postsData = try JSONDecoder().decode([PostData].self, from: data)
        let posts = postsData.map { $0.toPost() }
        return posts
    }
    
    /// Fetches posts based on a specific keyword (tag).
    /// - Parameter keyword: The hashtag to search for.
    /// - Returns: Array of `Post` objects.
    func fetchPosts(keyword: String) async throws -> [Post] {
        let endpoint = "timelines/tag/\(keyword)"
        guard let request = createRequest(endpoint: endpoint) else {
            throw MustardAppError(message: "Instance URL not set.")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postsData = try JSONDecoder().decode([PostData].self, from: data)
        let posts = postsData.map { $0.toPost() }
        return posts
    }
    
    /// Likes a specific post.
    /// - Parameter postID: The ID of the post to like.
    /// - Returns: The updated `Post` object.
    func likePost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/favourite"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    /// Unlikes a specific post.
    /// - Parameter postID: The ID of the post to unlike.
    /// - Returns: The updated `Post` object.
    func unlikePost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/unfavourite"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    /// Reblogs (reposts) a specific post.
    /// - Parameter postID: The ID of the post to reblog.
    /// - Returns: The updated `Post` object.
    func repost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/reblog"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    /// Undoreblogs (removes the repost) of a specific post.
    /// - Parameter postID: The ID of the post to undoreblog.
    /// - Returns: The updated `Post` object.
    func undoRepost(postID: String) async throws -> Post {
        let endpoint = "statuses/\(postID)/unreblog"
        guard let request = createRequest(endpoint: endpoint, method: "POST") else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    /// Comments on a specific post.
    /// - Parameters:
    ///   - postID: The ID of the post to comment on.
    ///   - content: The content of the comment.
    /// - Returns: The newly created `Post` object representing the comment.
    func comment(postID: String, content: String) async throws -> Post {
        let endpoint = "statuses"
        let parameters: [String: String] = [
            "status": content,
            "in_reply_to_id": postID
        ]
        guard let bodyData = parameters.percentEncoded(),
              let request = createRequest(endpoint: endpoint, method: "POST", body: bodyData) else {
            throw MustardAppError(message: "Unable to create request.")
        }
        return try await performPostAction(request: request)
    }
    
    // MARK: - Helper Methods
    
    /// Performs a POST action and returns the updated post.
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: The updated `Post` object.
    private func performPostAction(request: URLRequest) async throws -> Post {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let postData = try JSONDecoder().decode(PostData.self, from: data)
        let post = postData.toPost()
        return post
    }
    
    /// Validates the HTTP response.
    /// - Parameter response: The URLResponse to validate.
    /// - Throws: `MustardAppError` if the response status code is not 200-299.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MustardAppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MustardAppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
}

/// Extension to encode dictionary parameters for URL-encoded requests.
extension Dictionary where Key == String, Value == String {
    /// Percent-encodes the dictionary into URL-encoded data.
    /// - Returns: URL-encoded `Data` or nil if encoding fails.
    func percentEncoded() -> Data? {
        return map { key, value in
            let keyString = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let valueString = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(keyString)=\(valueString)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
