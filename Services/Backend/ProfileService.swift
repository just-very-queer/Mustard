//
//  ProfileService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Updated to use MastodonAPIService
//

import Foundation
import OSLog

class ProfileService {
    private let mastodonAPIService: MastodonAPIService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "ProfileService")

    /// Designated initializer — inject the shared MastodonAPIService instance
    init(mastodonAPIService: MastodonAPIService = MustardApp.mastodonAPIServiceInstance) {
        self.mastodonAPIService = mastodonAPIService
    }

    /// Fetch the followers of an account
    func fetchFollowers(for accountId: String) async throws -> [User] {
        logger.debug("Fetching followers for account: \(accountId)")
        let followers = try await mastodonAPIService.fetchAccountFollowers(accountId: accountId)
        logger.debug("Fetched \(followers.count) followers for account: \(accountId)")
        return followers
    }

    /// Fetch the accounts that a given account is following
    func fetchFollowing(for accountId: String) async throws -> [User] {
        logger.debug("Fetching following for account: \(accountId)")
        let following = try await mastodonAPIService.fetchAccountFollowing(accountId: accountId)
        logger.debug("Fetched \(following.count) following for account: \(accountId)")
        return following
    }

    /// Fetch the statuses (posts) of an account, with optional media-only or replies-excluded filters
    func fetchStatuses(
        for accountId: String,
        onlyMedia: Bool = false,
        excludeReplies: Bool = true
    ) async throws -> [Post] {
        logger.debug("Fetching statuses for account: \(accountId), onlyMedia: \(onlyMedia), excludeReplies: \(excludeReplies)")
        let posts = try await mastodonAPIService.fetchAccountStatuses(
            accountId: accountId,
            onlyMedia: onlyMedia,
            excludeReplies: excludeReplies
        )
        logger.debug("Fetched \(posts.count) statuses for account: \(accountId)")
        return posts
    }

    /// Update the authenticated user's profile with the given fields
    func updateProfile(for accountId: String, updatedFields: [String: String]) async throws -> User {
        logger.debug("Updating profile for account: \(accountId) with fields: \(updatedFields.keys)")
        let updatedUser = try await mastodonAPIService.updateCurrentUserProfile(fields: updatedFields)
        logger.debug("Profile updated for account: \(accountId)")
        return updatedUser
    }

    /// Fetch media posts for a user, with optional pagination.
    func fetchUserMediaPosts(accountID: String, maxId: String? = nil) async throws -> [Post] {
        logger.debug("Fetching media posts for account: \(accountID), maxId: \(maxId ?? "nil")")
        let posts = try await mastodonAPIService.WorkspaceUserMediaPosts(
            accountID: accountID,
            onlyMedia: true, // Hardcoded to true for media gallery
            maxId: maxId
        )
        logger.debug("Fetched \(posts.count) media posts for account: \(accountID)")
        return posts
    }
}
