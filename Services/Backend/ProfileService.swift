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

    // Fetch Followers
    func fetchFollowers(for accountId: String) async throws -> [User] {
        let endpoint = "/api/v1/accounts/\(accountId)/followers"
        guard let url = try? await networkService.endpointURL(endpoint) else {
            throw AppError(network: .invalidURL) // Use NetworkError.invalidURL
        }
        return try await networkService.fetchData(url: url, method: "GET", type: [User].self)
    }

    // Fetch Following
    func fetchFollowing(for accountId: String) async throws -> [User] {
        let endpoint = "/api/v1/accounts/\(accountId)/following"
        guard let url = try? await networkService.endpointURL(endpoint) else {
            throw AppError(network: .invalidURL) // Use NetworkError.invalidURL
        }
        return try await networkService.fetchData(url: url, method: "GET", type: [User].self)
    }

    // Update Profile
    func updateProfile(for accountId: String, updatedFields: [String: String]) async throws -> User {
        let endpoint = "/api/v1/accounts/\(accountId)"
        return try await networkService.postData(
            endpoint: endpoint,
            body: updatedFields,
            responseType: User.self
        )
    }
}
