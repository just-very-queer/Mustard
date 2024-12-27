//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
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
    
    // MARK: - Enum: TimeFilter
    
    enum TimeFilter: String, CaseIterable, Identifiable {
        case hour = "Hour"
        case day = "Day"
        case week = "Week"
        case all = "All"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Private Properties
    
    private let mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        
        // Observe authentication notifications (optional)
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
        
        // Load persisted filter from user defaults
        if let saved = UserDefaults.standard.string(forKey: "SelectedFilter"),
           let savedFilter = TimeFilter(rawValue: saved) {
            self.selectedFilter = savedFilter
        }
        
        // If already have a token, fetch timeline
        if mastodonService.accessToken != nil {
            Task {
                await fetchTimeline()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetches the user's timeline from the service (optionally cached),
    /// then filters & sorts the results based on `selectedFilter`.
    func fetchTimeline() async {
        guard mastodonService.baseURL != nil else {
            self.alertError = AppError(message: "Instance URL not set. Please log in.")
            return
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            // Here we call `fetchTimeline(useCache:)`.
            // If you want immediate cached data, pass `useCache: true`.
            // If you want a forced network request, pass `useCache: false`.
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: true)
            
            // Now filter by date range
            let filtered = filterPosts(fetchedPosts, basedOn: selectedFilter)
            // Sort newest first
            self.posts = filtered.sorted { $0.createdAt > $1.createdAt }
        } catch {
            self.alertError = AppError(message: "Failed to fetch timeline: \(error.localizedDescription)")
        }
    }
    
    /// Toggles the like status of a post.
    func toggleLike(post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            // Locally update
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isFavourited.toggle()
                posts[idx].favouritesCount += posts[idx].isFavourited ? 1 : -1
            }
        } catch {
            self.alertError = AppError(message: "Failed to toggle like: \(error.localizedDescription)")
        }
    }
    
    /// Toggles the repost status of a post.
    func toggleRepost(post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            // Locally update
            if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                posts[idx].isReblogged.toggle()
                posts[idx].reblogsCount += posts[idx].isReblogged ? 1 : -1
            }
        } catch {
            self.alertError = AppError(message: "Failed to toggle repost: \(error.localizedDescription)")
        }
    }
    
    /// Comments on a post.
    func comment(post: Post, content: String) async throws {
        try await mastodonService.comment(postID: post.id, content: content)
        // Optionally increment repliesCount
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].repliesCount += 1
        }
    }
    
    // MARK: - Private Methods
    
    /// Filters posts based on the user-selected timeframe (hour/day/week/all).
    private func filterPosts(_ posts: [Post], basedOn filter: TimeFilter) -> [Post] {
        let now = Date()
        let calendar = Calendar.current
        
        switch filter {
        case .hour:
            let cutoff = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
            return posts.filter { $0.createdAt >= cutoff }
        case .day:
            let cutoff = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return posts.filter { $0.createdAt >= cutoff }
        case .week:
            let cutoff = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return posts.filter { $0.createdAt >= cutoff }
        case .all:
            return posts
        }
    }
}

