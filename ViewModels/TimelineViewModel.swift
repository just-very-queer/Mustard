//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
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
    @Published var selectedFilter: TimeFilter = TimeFilter.allCases.first ?? .day
    
    // MARK: - Enums
    
    enum TimeFilter: String, CaseIterable, Identifiable {
        case hour = "Hour"
        case day = "Day"
        case week = "Week"
        case all = "All"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Private Properties
    
    private var mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        
        // Observe authentication changes
        NotificationCenter.default.publisher(for: .didAuthenticate)
            .sink { [weak self] _ in
                Task {
                    await self?.fetchTimeline()
                }
            }
            .store(in: &cancellables)
        
        // Observe filter changes and persist them
        $selectedFilter
            .sink { newFilter in
                UserDefaults.standard.set(newFilter.rawValue, forKey: "SelectedFilter")
                Task {
                    await self.fetchTimeline()
                }
            }
            .store(in: &cancellables)
        
        // Load persisted filter
        if let savedFilter = UserDefaults.standard.string(forKey: "SelectedFilter"),
           let filter = TimeFilter(rawValue: savedFilter) {
            self.selectedFilter = filter
        }
        
        // If already authenticated, fetch timeline
        if mastodonService.accessToken != nil {
            Task {
                await fetchTimeline()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches the user's timeline from Mastodon based on the selected filter.
    func fetchTimeline() async {
        guard let _ = mastodonService.baseURL else {
            self.alertError = AppError(message: "Instance URL not set.")
            return
        }
        
        self.isLoading = true // Start loading
        defer { self.isLoading = false } // Ensure loading stops
        
        do {
            let fetchedPosts = try await mastodonService.fetchTimeline()
            let filteredPosts = filterPosts(fetchedPosts, basedOn: selectedFilter)
            let sortedPosts = filteredPosts.sorted { $0.createdAt > $1.createdAt } // Most recent first
            self.posts = sortedPosts
        } catch {
            self.alertError = AppError(message: "Failed to fetch timeline: \(error.localizedDescription)")
        }
    }
    
    /// Toggles the like status of a post.
    /// - Parameter post: The post to like or unlike.
    func toggleLike(post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            // Update the post locally
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isFavourited.toggle()
                posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
            }
        } catch {
            self.alertError = AppError(message: "Failed to toggle like: \(error.localizedDescription)")
        }
    }
    
    /// Toggles the repost (reblog) status of a post.
    /// - Parameter post: The post to repost or unrepost.
    func toggleRepost(post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            // Update the post locally
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isReblogged.toggle()
                posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
            }
        } catch {
            self.alertError = AppError(message: "Failed to toggle repost: \(error.localizedDescription)")
        }
    }
    
    /// Adds a comment to a post.
    /// - Parameters:
    ///   - post: The post to comment on.
    ///   - content: The content of the comment.
    func comment(post: Post, content: String) async throws {
        try await mastodonService.comment(postID: post.id, content: content)
        // Optionally, refresh repliesCount
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].repliesCount += 1
        }
    }
    
    // MARK: - Private Methods
    
    /// Filters posts based on the selected time frame.
    /// - Parameters:
    ///   - posts: The array of posts to filter.
    ///   - filter: The selected time filter.
    /// - Returns: An array of filtered posts.
    private func filterPosts(_ posts: [Post], basedOn filter: TimeFilter) -> [Post] {
        let calendar = Calendar.current
        let now = Date()
        let filteredDate: Date
        
        switch filter {
        case .hour:
            filteredDate = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        case .day:
            filteredDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .week:
            filteredDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .all:
            return posts
        }
        
        return posts.filter { $0.createdAt >= filteredDate }
    }
}

