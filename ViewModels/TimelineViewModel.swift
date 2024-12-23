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
    
    @Published var instanceURL: URL? {
        didSet {
            mastodonService.baseURL = instanceURL
        }
    }
    
    private var mastodonService: MastodonServiceProtocol
    
    /// Initializes the view model with a Mastodon service.
    /// - Parameter mastodonService: The service to use for Mastodon interactions.
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
    /// - Parameter keyword: The hashtag to search for.
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
    /// - Parameter updatedPost: The updated `Post` object.
    func updatePost(_ updatedPost: Post) {
        if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
            posts[index] = updatedPost
        }
    }
}
