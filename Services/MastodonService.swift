//
//  MastodonService.swift
//  Mustard
//
//  Created by Your Name on [Date].
//

import Foundation

/// Service responsible for interacting with a Mastodon-like backend.
class MastodonService: MastodonServiceProtocol {
    
    // MARK: - Properties
    
    var baseURL: URL?
    var accessToken: String? {
        get {
            guard let baseURL = baseURL else {
                print("[MastodonService] accessToken getter: baseURL not set.")
                return nil
            }
            let service = "Mustard-\(baseURL.host ?? "unknown")"
            do {
                return try KeychainHelper.shared.read(service: service, account: "accessToken")
            } catch {
                print("[MastodonService] Failed to retrieve access token: \(error)")
                return nil
            }
        }
        set {
            guard let baseURL = baseURL else {
                print("[MastodonService] accessToken setter: baseURL not set.")
                return
            }
            let service = "Mustard-\(baseURL.host ?? "unknown")"
            if let token = newValue {
                do {
                    try KeychainHelper.shared.save(token, service: service, account: "accessToken")
                    print("[MastodonService] Token saved successfully in Keychain.")
                } catch {
                    print("[MastodonService] Failed to save token: \(error)")
                }
            } else {
                do {
                    try KeychainHelper.shared.delete(service: service, account: "accessToken")
                    print("[MastodonService] Token deleted successfully from Keychain.")
                } catch {
                    print("[MastodonService] Failed to delete token: \(error)")
                }
            }
        }
    }
    
    // MARK: - Timeline Cache
    
    private var cachedPosts: [Post] = []
    private var cacheFileURL: URL? {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDir.appendingPathComponent("mustard_timeline.json")
    }
    
    // MARK: - Init
    
    init(baseURL: URL? = nil) {
        self.baseURL = baseURL
        loadTimelineFromDisk()
    }
    
    // MARK: - MastodonServiceProtocol
    
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        if useCache, !cachedPosts.isEmpty {
            print("[MastodonService] Returning in-memory cached posts immediately.")
            Task.detached { [weak self] in
                await self?.backgroundRefreshTimeline()
            }
            return cachedPosts
        }
        
        guard let baseURL = baseURL else {
            throw NSError(domain: "[MastodonService] No baseURL set.", code: -1)
        }
        guard let token = accessToken else {
            throw NSError(domain: "[MastodonService] No access token set.", code: -2)
        }
        
        let timelineURL = baseURL.appendingPathComponent("/api/v1/timelines/home")
        var request = URLRequest(url: timelineURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let postData = try decoder.decode([PostData].self, from: data)
        let posts = postData.map { $0.toPost() }
        
        cachedPosts = posts
        saveTimelineToDisk(posts)
        
        return posts
    }
    
    func clearTimelineCache() {
        cachedPosts.removeAll()
        guard let fileURL = cacheFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
        print("[MastodonService] Timeline cache cleared.")
    }
    
    func saveAccessToken(_ token: String) throws {
        guard let baseURL = baseURL else {
            throw NSError(domain: "[MastodonService] baseURL not set.", code: -1)
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")"
        try KeychainHelper.shared.save(token, service: service, account: "accessToken")
    }
    
    func clearAccessToken() throws {
        guard let baseURL = baseURL else {
            throw NSError(domain: "[MastodonService] baseURL not set.", code: -1)
        }
        let service = "Mustard-\(baseURL.host ?? "unknown")"
        try KeychainHelper.shared.delete(service: service, account: "accessToken")
    }
    
    func retrieveAccessToken() throws -> String? {
        accessToken
    }
    
    func retrieveInstanceURL() throws -> URL? {
        return baseURL
    }
    
    func toggleLike(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/favourite")
    }
    
    func toggleRepost(postID: String) async throws {
        try await toggleAction(for: postID, endpoint: "/reblog")
    }
    
    func comment(postID: String, content: String) async throws {
        guard let baseURL = baseURL else {
            throw NSError(domain: "[MastodonService] baseURL not set.", code: -1)
        }
        guard let token = accessToken else {
            throw NSError(domain: "[MastodonService] No access token set.", code: -2)
        }
        
        let commentURL = baseURL.appendingPathComponent("/api/v1/statuses")
        var request = URLRequest(url: commentURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "status": content,
            "in_reply_to_id": postID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("[MastodonService] Comment posted successfully.")
    }
    
    /// The crucial method: It's `async throws` so we must use `try await` in AccountsViewModel.
    func registerAccount(username: String,
                         password: String,
                         instanceURL: URL) async throws -> Account {
        // In real usage, do a network call here to create the account. For now, mock it:
        let newAccount = Account(
            id: UUID().uuidString,
            username: username,
            displayName: username,
            avatar: URL(string: "https://example.com/default_avatar.png")!,
            acct: username,
            instanceURL: instanceURL,
            accessToken: "mockAccessToken123"
        )
        return newAccount
    }
    
    // MARK: - Private Helpers
    
    private func toggleAction(for postID: String, endpoint: String) async throws {
        guard let baseURL = baseURL else {
            throw NSError(domain: "[MastodonService] baseURL not set.", code: -1)
        }
        guard let token = accessToken else {
            throw NSError(domain: "[MastodonService] No access token set.", code: -2)
        }
        
        let url = baseURL.appendingPathComponent("/api/v1/statuses/\(postID)\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        print("[MastodonService] Action toggled for postID=\(postID)")
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResp = response as? HTTPURLResponse,
              (200...299).contains(httpResp.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NSError(domain: "[MastodonService] HTTP error code: \(code)", code: code)
        }
    }
    
    private func backgroundRefreshTimeline() async {
        do {
            _ = try await fetchTimeline(useCache: false)
            print("[MastodonService] Background refresh successful.")
        } catch {
            print("[MastodonService] Background refresh failed: \(error)")
        }
    }
    
    private func saveTimelineToDisk(_ posts: [Post]) {
        guard let fileURL = cacheFileURL else { return }
        DispatchQueue.global(qos: .background).async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            do {
                let data = try encoder.encode(posts)
                try data.write(to: fileURL, options: .atomic)
                print("[MastodonService] Timeline cached to disk.")
            } catch {
                print("[MastodonService] Failed to save timeline: \(error)")
            }
        }
    }
    
    private func loadTimelineFromDisk() {
        guard let fileURL = cacheFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedPosts = try decoder.decode([Post].self, from: data)
            cachedPosts = loadedPosts
            print("[MastodonService] Timeline loaded from disk. Count: \(cachedPosts.count)")
        } catch {
            print("[MastodonService] Failed to load timeline: \(error)")
        }
    }
}

