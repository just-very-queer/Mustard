//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TimelineViewModel: ObservableObject {
    
    // MARK: - Published Properties

    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var alertError: AppError?
    
    // MARK: - Private Properties

    private let mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isFetching: Bool = false // Prevents overlapping fetches
    private var currentPage: Int = 1 // For pagination
    
    // MARK: - Initialization

    /// Initializes the TimelineViewModel with a MastodonServiceProtocol.
    ///
    /// - Parameter mastodonService: The service to interact with Mastodon. Defaults to `MastodonService.shared`.
    init(mastodonService: MastodonServiceProtocol? = nil) {
        // Assign the provided service or default to MastodonService.shared within the actor context
        self.mastodonService = mastodonService ?? MastodonService.shared

        // Observe authentication success to fetch timeline
        NotificationCenter.default.publisher(for: .didAuthenticate)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchTimeline()
                }
            }
            .store(in: &cancellables)

        // Initial fetch
        Task {
            await fetchTimelineIfNeeded()
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches the timeline if the access token and base URL are set.
    func fetchTimelineIfNeeded() async {
        do {
            guard let _ = try await mastodonService.retrieveInstanceURL(),
                  let _ = try await mastodonService.retrieveAccessToken() else {
                alertError = AppError(message: "Instance URL or Access Token not set. Please log in.")
                return
            }
            await fetchTimeline()
        } catch {
            alertError = AppError(message: "Failed to retrieve credentials: \(error.localizedDescription)", underlyingError: error)
        }
    }

    /// Fetches the timeline from the Mastodon service.
    func fetchTimeline() async {
        os_log("Attempting to fetch timeline. isFetching: %{public}@, isLoading: %{public}@", log: .default, type: .debug, "\(isFetching)", "\(isLoading)")
        guard !isFetching else { return } // Prevent overlapping fetches
        isFetching = true
        isLoading = true
        defer {
            isLoading = false
            isFetching = false
        }

        do {
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: true)
            self.posts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
            self.currentPage = 1 // Reset to first page on initial fetch
            os_log("Timeline fetched with %{public}d posts.", log: .default, type: .info, fetchedPosts.count)
        } catch {
            if let serviceError = error as? MastodonServiceError {
                alertError = AppError(message: "Failed to fetch timeline: \(serviceError.localizedDescription)", underlyingError: error)
            } else {
                alertError = AppError(message: "Failed to fetch timeline: \(error.localizedDescription)", underlyingError: error)
            }
            os_log("Error fetching timeline: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    /// Fetches more timeline data for pagination.
    func fetchMoreTimeline() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        
        let nextPage = currentPage + 1
        do {
            let morePosts = try await mastodonService.fetchTimeline(page: nextPage, useCache: false)
            // Avoid duplicates
            let newPosts = morePosts.filter { newPost in
                !self.posts.contains(where: { $0.id == newPost.id })
            }
            self.posts.append(contentsOf: newPosts.sorted { $0.createdAt > $1.createdAt })
            self.currentPage = nextPage
            os_log("Fetched more timeline posts. Current page: %{public}d", log: .default, type: .info, nextPage)
        } catch {
            if let serviceError = error as? MastodonServiceError {
                alertError = AppError(message: "Failed to load more posts: \(serviceError.localizedDescription)", underlyingError: error)
            } else {
                alertError = AppError(message: "Failed to load more posts: \(error.localizedDescription)", underlyingError: error)
            }
            os_log("Error fetching more timeline: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// Toggles the like status of a post.
    /// - Parameter post: The post to like or unlike.
    func toggleLike(post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isFavourited.toggle()
                posts[idx].favouritesCount += posts[idx].isFavourited ? 1 : -1
                os_log("Toggled like for postID: %{public}@", log: .default, type: .info, post.id)
            }
        } catch {
            if let serviceError = error as? MastodonServiceError {
                alertError = AppError(message: "Failed to toggle like: \(serviceError.localizedDescription)", underlyingError: error)
            } else {
                alertError = AppError(message: "Failed to toggle like: \(error.localizedDescription)", underlyingError: error)
            }
            os_log("Error toggling like: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// Toggles the repost status of a post.
    /// - Parameter post: The post to repost or un-repost.
    func toggleRepost(post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isReblogged.toggle()
                posts[idx].reblogsCount += posts[idx].isReblogged ? 1 : -1
                os_log("Toggled repost for postID: %{public}@", log: .default, type: .info, post.id)
            }
        } catch {
            if let serviceError = error as? MastodonServiceError {
                alertError = AppError(message: "Failed to toggle repost: \(serviceError.localizedDescription)", underlyingError: error)
            } else {
                alertError = AppError(message: "Failed to toggle repost: \(error.localizedDescription)", underlyingError: error)
            }
            os_log("Error toggling repost: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// Comments on a specific post.
    /// - Parameters:
    ///   - post: The post to comment on.
    ///   - content: The content of the comment.
    func comment(post: Post, content: String) async throws {
        do {
            try await mastodonService.comment(postID: post.id, content: content)
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].repliesCount += 1
                os_log("Comment added to postID: %{public}@", log: .default, type: .info, post.id)
            }
        } catch {
            if let serviceError = error as? MastodonServiceError {
                alertError = AppError(message: "Failed to comment: \(serviceError.localizedDescription)", underlyingError: error)
            } else {
                alertError = AppError(message: "Failed to comment: \(error.localizedDescription)", underlyingError: error)
            }
            os_log("Error commenting on post: %{public}@", log: .default, type: .error, error.localizedDescription)
            throw error
        }
    }
}

