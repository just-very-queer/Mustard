//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftUI

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var alertError: MustardAppError?

    /// This must be set before calling loadTimeline()
    @Published var instanceURL: URL? {
        didSet {
            mastodonService.baseURL = instanceURL
        }
    }

    private var mastodonService: MastodonServiceProtocol

    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
    }

    /// Loads the home timeline asynchronously.
    func loadTimeline() async {
        guard instanceURL != nil else {
            alertError = MustardAppError(message: "Instance URL not set.")
            return
        }
        isLoading = true
        do {
            let fetchedPosts = try await mastodonService.fetchHomeTimeline()
            posts = fetchedPosts
        } catch {
            alertError = MustardAppError(message: error.localizedDescription)
        }
        isLoading = false
    }

    /// Loads posts based on a specific keyword asynchronously.
    func loadPosts(keyword: String) async {
        guard instanceURL != nil else {
            alertError = MustardAppError(message: "Instance URL not set.")
            return
        }
        isLoading = true
        do {
            let fetchedPosts = try await mastodonService.fetchPosts(keyword: keyword)
            posts = fetchedPosts
        } catch {
            alertError = MustardAppError(message: error.localizedDescription)
        }
        isLoading = false
    }

    /// Updates a post in the `posts` array.
    func updatePost(_ updatedPost: Post) {
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[index] = updatedPost
        }
    }

    // MARK: - Action Handlers

    func toggleLike(post: Post) async {
        do {
            if post.isFavourited {
                let updatedPost = try await mastodonService.unlikePost(postID: post.id)
                updatePost(updatedPost)
            } else {
                let updatedPost = try await mastodonService.likePost(postID: post.id)
                updatePost(updatedPost)
            }
        } catch {
            alertError = MustardAppError(message: error.localizedDescription)
        }
    }

    func toggleRepost(post: Post) async {
        do {
            if post.isReblogged {
                let updatedPost = try await mastodonService.undoRepost(postID: post.id)
                updatePost(updatedPost)
            } else {
                let updatedPost = try await mastodonService.repost(postID: post.id)
                updatePost(updatedPost)
            }
        } catch {
            alertError = MustardAppError(message: error.localizedDescription)
        }
    }

    func comment(post: Post, content: String) async {
        do {
            let comment = try await mastodonService.comment(postID: post.id, content: content)
            // Optionally insert the new comment at the top
            posts.insert(comment, at: 0)
        } catch {
            alertError = MustardAppError(message: error.localizedDescription)
        }
    }
}

