//
//  ProfileService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog

class ProfileService {
    private let networkService: NetworkService
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "ProfileService")

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchFollowers(for accountId: String) async throws -> [User] {
        // Implement logic to fetch followers using NetworkService
        // Example endpoint (adjust based on actual Mastodon API):
        let endpoint = "/api/v1/accounts/\(accountId)/followers"
        let url = try await networkService.endpointURL(endpoint)
        return try await networkService.fetchData(url: url, method: "GET", type: [User].self)
    }

    func fetchFollowing(for accountId: String) async throws -> [User] {
        // Implement logic to fetch following using NetworkService
        // Example endpoint (adjust based on actual Mastodon API):
        let endpoint = "/api/v1/accounts/\(accountId)/following"
        let url = try await networkService.endpointURL(endpoint)
        return try await networkService.fetchData(url: url, method: "GET", type: [User].self)
    }

    func updateProfile(for accountId: String, updatedFields: [String: String]) async throws {
        // Implement logic to update profile fields using NetworkService
        // Example endpoint (adjust based on actual Mastodon API):
        let endpoint = "/api/v1/accounts/\(accountId)" // Assuming PATCH method for updates

        // You might need to adjust the header and content type based on the API requirements
        let _ = try await networkService.postData(endpoint: endpoint, body: updatedFields, type: User.self, contentType: "application/json")
        // Consider returning the updated User object if the API returns it
    }
}
