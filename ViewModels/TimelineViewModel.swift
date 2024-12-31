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
    @Published var alertError: AppError? // Updated to use AppError

    // MARK: - Private Properties

    private let mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var isFetching: Bool = false // Prevents overlapping fetches

    // MARK: - Initialization

    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService

        NotificationCenter.default.publisher(for: .didAuthenticate)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchTimeline()
                }
            }
            .store(in: &cancellables)

        Task {
            await fetchTimelineIfNeeded()
        }
    }

    // MARK: - Public Methods

    /// Fetches the timeline if the access token and base URL are set.
    func fetchTimelineIfNeeded() async {
        do {
            guard let _ = try mastodonService.retrieveInstanceURL(),
                  let _ = try mastodonService.retrieveAccessToken() else {
                alertError = AppError(message: "Instance URL or Access Token not set. Please log in.")
                return
            }
            await fetchTimeline()
        } catch {
            alertError = AppError(message: "Failed to retrieve credentials: \(error.localizedDescription)")
        }
    }

    /// Fetches the timeline from the Mastodon service.
    func fetchTimeline() async {
        guard !isFetching else { return } // Prevent overlapping fetches
        isFetching = true
        isLoading = true
        defer {
            isLoading = false
            isFetching = false
        }

        do {
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: true)
            posts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
        } catch {
            alertError = AppError(message: "Failed to fetch timeline: \(error.localizedDescription)")
            // isLoading is already set to false by defer
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
            }
        } catch {
            alertError = AppError(message: "Failed to toggle like: \(error.localizedDescription)")
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
            }
        } catch {
            alertError = AppError(message: "Failed to toggle repost: \(error.localizedDescription)")
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
            }
        } catch {
            alertError = AppError(message: "Failed to comment: \(error.localizedDescription)")
            throw error
        }
    }
}

