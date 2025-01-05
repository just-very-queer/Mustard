//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
class TimelineViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var alertError: AppError?
    
    // MARK: - Private Properties
    private let mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isFetching = false
    private var currentPage = 1

    // Logger for debugging
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "TimelineViewModel")
    
    // MARK: - Initialization
    init(mastodonService: MastodonServiceProtocol? = nil) {
        self.mastodonService = mastodonService ?? MastodonService.shared
        NotificationCenter.default.publisher(for: .didAuthenticate)
            .sink { [weak self] _ in
                Task { await self?.fetchTimelineIfAuthenticated() }
            }
            .store(in: &cancellables)

        Task { await fetchTimelineIfAuthenticated() }
    }
    
    // MARK: - Public API

    /// Ensures the user is authenticated before fetching the timeline.
    func fetchTimelineIfAuthenticated() async {
        do {
            // Ensure MastodonService is initialized
            await MastodonService.shared.ensureInitialized()  // Updated call

            // Validate credentials
            guard let baseURL = try await mastodonService.retrieveInstanceURL(),
                  let accessToken = try await mastodonService.retrieveAccessToken(),
                  !baseURL.absoluteString.isEmpty,
                  !accessToken.isEmpty else {
                os_log("fetchTimelineIfAuthenticated: Missing credentials.", log: logger, type: .error)
                throw AppError(mastodon: .missingCredentials)
            }

            os_log("Authentication validated with base URL: %{public}@", log: logger, type: .info, baseURL.absoluteString)

            // Fetch the timeline
            await fetchTimeline()
        } catch {
            handleError("Authentication validation failed", error)
        }
    }

    /// Fetches the timeline from the Mastodon service.
    func fetchTimeline() async {
        guard !isFetching else { return }
        isFetching = true
        isLoading = true
        defer {
            isLoading = false
            isFetching = false
        }
        do {
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: true)
            posts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
            currentPage = 1
        } catch {
            handleError("Failed to fetch timeline", error)
        }
    }
    
    /// Fetches the next page of timeline data for pagination.
    func fetchMoreTimeline() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        
        do {
            let nextPagePosts = try await mastodonService.fetchTimeline(page: currentPage + 1, useCache: false)
            let newPosts = nextPagePosts.filter { np in !posts.contains(where: { $0.id == np.id }) }
            posts.append(contentsOf: newPosts.sorted { $0.createdAt > $1.createdAt })
            currentPage += 1
        } catch {
            handleError("Failed to load more posts", error)
        }
    }

    /// Toggles the like status of a given `Post`.
    func toggleLike(post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isFavourited.toggle()
                posts[idx].favouritesCount += posts[idx].isFavourited ? 1 : -1
            }
        } catch {
            handleError("Failed to toggle like", error)
        }
    }

    /// Toggles the repost status of a given `Post`.
    func toggleRepost(post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isReblogged.toggle()
                posts[idx].reblogsCount += posts[idx].isReblogged ? 1 : -1
            }
        } catch {
            handleError("Failed to toggle repost", error)
        }
    }

    /// Comments on a given `Post`.
    func comment(post: Post, content: String) async throws {
        do {
            try await mastodonService.comment(postID: post.id, content: content)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].repliesCount += 1
            }
        } catch {
            handleError("Failed to comment", error)
            throw error
        }
    }
    
    // MARK: - Private Helpers

    /// Handles errors and updates the alert state.
    private func handleError(_ msg: String, _ error: Error) {
        os_log("%{public}@ Error: %{public}@", log: logger, type: .error, msg, error.localizedDescription)
        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: "\(msg): \(error.localizedDescription)", underlyingError: error)
        }
    }
}
