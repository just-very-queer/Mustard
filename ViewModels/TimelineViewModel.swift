//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
// (REVISED: Added explicit 'self.' captures in closures and fixed unused result warnings)

import Foundation
import Combine
import CoreLocation
import SwiftUI
import OSLog

@MainActor
final class TimelineViewModel: ObservableObject {
    // MARK: - Filter Enum (Updated)
    enum TimelineFilter: String, CaseIterable, Identifiable {
        case latest = "Latest"       // Fetches home timeline
        case trending = "Trending"   // Fetches trending statuses
        // case following = "Following" // Requires more complex logic/API - Omitted for now
        // case local = "Local"       // Requires specific API endpoint - Omitted for now
        // case federated = "Federated" // Requires specific API endpoint - Omitted for now
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Published Properties
    @Published private(set) var posts: [Post] = [] // Combined list for the selected filter
    @Published var selectedFilter: TimelineFilter = .latest { // Default to Latest
        didSet {
            if oldValue != selectedFilter {
                // Fetch new data when filter changes, don't just filter locally
                // Use self. here
                logger.info("Filter changed to \(self.selectedFilter.rawValue). Refreshing data.")
                self.posts = [] // Clear existing posts immediately for visual feedback
                self.initializeTimelineData() // Fetch data for the new filter
            }
        }
    }
    // 'filteredPosts' is removed - 'posts' now holds the content for the selected filter
    @Published private(set) var topPosts: [Post] = [] // Keep for the separate horizontal trending section
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isFetchingMore = false
    @Published var alertError: AppError?
    @Published var navigationPath = NavigationPath() // Keep for navigation
    
    @Published var selectedPostForComments: Post?
    @Published var showingCommentSheet = false
    @Published var commentText: String = ""
    @Published private(set) var postLoadingStates: [String: Bool] = [:]
    
    // Pagination Tracking - Store next page URLs or max_id/since_id
    private var nextPageInfo: String? = nil // Example: Could be max_id or a full URL
    
    // MARK: - Services
    private let timelineService: TimelineService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private let trendingService: TrendingService // Kept for separate topPosts section if needed
    private let cacheService: CacheService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineViewModel")
    
    // MARK: - Initialization
    init(
        timelineService: TimelineService,
        locationManager: LocationManager,
        trendingService: TrendingService,
        postActionService: PostActionService,
        cacheService: CacheService
    ) {
        self.timelineService = timelineService
        self.locationManager = locationManager
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.cacheService = cacheService
        // No subscriptions needed here if fetching is driven by actions/appear
    }
    
    // MARK: - Data Fetching Triggers (Updated for Filters)
    
    func initializeTimelineData() {
        // Don't fetch if already loading
        guard !isLoading else { return }
        
        // Use self. here
        logger.info("Initializing timeline data for filter: \(self.selectedFilter.rawValue)...")
        isLoading = true
        isFetchingMore = false // Reset pagination state
        nextPageInfo = nil    // Reset pagination state
        alertError = nil
        
        Task {
            // Use weak self capture if necessary, though @MainActor might mitigate some cycle risks
            // [weak self] in // Optional: Use weak self if you suspect retain cycles
            
            // Ensure loading state is reset
            // Use self. here
            defer { self.isLoading = false }
            
            // guard let self = self else { return } // Uncomment if using [weak self]
            
            do {
                let fetchedPosts: [Post]
                // Use self. here
                switch self.selectedFilter {
                case .latest:
                    fetchedPosts = try await self.timelineService.fetchHomeTimeline(maxId: nil)
                    self.nextPageInfo = fetchedPosts.last?.id
                case .trending:
                    fetchedPosts = try await self.timelineService.fetchTrendingTimeline()
                    self.nextPageInfo = nil
                }
                // Use self. here
                self.posts = fetchedPosts
                self.initializeLoadingStates(for: fetchedPosts)
                
                await self.fetchTopPostsForHeader()
                
            } catch {
                // Use self. here
                self.logger.error("Failed to initialize timeline: \(error.localizedDescription)")
                self.handleFetchError(error)
            }
        }
    }
    
    func fetchMoreTimeline() {
        // Use self. here for all property accesses in the guard condition
        guard !self.isLoading, !self.isFetchingMore, let pageInfo = self.nextPageInfo, self.selectedFilter == .latest else {
            logger.debug("Cannot fetch more. isLoading: \(self.isLoading), isFetchingMore: \(self.isFetchingMore), nextPageInfo: \(self.nextPageInfo ?? "nil"), filter: \(self.selectedFilter.rawValue)")
            return
        }
        
        logger.info("Fetching more timeline posts (using page info: \(pageInfo))...")
        // Use self. here
        self.isFetchingMore = true
        self.alertError = nil
        
        Task {
            // [weak self] in // Optional weak self capture
            // Ensure fetchingMore is reset
            // Use self. here
            defer { self.isFetchingMore = false }
            // guard let self = self else { return } // Uncomment if using [weak self]
            
            do {
                let newPosts: [Post]
                // Use self. here
                switch self.selectedFilter {
                case .latest:
                    newPosts = try await self.timelineService.fetchHomeTimeline(maxId: pageInfo)
                    self.nextPageInfo = newPosts.last?.id
                case .trending:
                    newPosts = []
                    self.nextPageInfo = nil
                }
                
                if !newPosts.isEmpty {
                    // Use self. here
                    self.posts.append(contentsOf: newPosts)
                    self.initializeLoadingStates(for: newPosts)
                } else {
                    // Use self. here
                    self.nextPageInfo = nil
                    self.logger.info("No more posts found for pagination.")
                }
            } catch {
                // Use self. here
                self.logger.error("Failed to fetch more timeline posts: \(error.localizedDescription)")
                self.handleFetchError(error)
            }
        }
    }
    
    func refreshTimeline() {
        // Use self. here
        logger.info("Refreshing timeline for filter: \(self.selectedFilter.rawValue)...")
        initializeTimelineData()
    }
    
    // Fetch separate top posts for the horizontal view
    private func fetchTopPostsForHeader() async {
        logger.debug("Fetching top posts for horizontal header...")
        do {
            // Use self. here
            self.topPosts = try await trendingService.fetchTopPosts()
        } catch {
            logger.error("Failed to fetch top posts for header: \(error.localizedDescription)")
            // Use self. here
            self.topPosts = [] // Clear on error
        }
    }
    
    private func handleFetchError(_ error: Error) {
        if (error as? URLError)?.code == .cancelled {
            logger.info("Timeline fetch task cancelled.")
            return
        }
        // Use self. here
        self.alertError = AppError(message: "Failed to load timeline", underlyingError: error)
        self.posts = [] // Clear posts on significant error
    }
    
    
    // MARK: - Post Actions
    
    func toggleLike(for post: Post) {
        let originalPost = post // Keep a copy for potential rollback
        let originalIndex = posts.firstIndex(where: { $0.id == post.id })
        let originalTopIndex = topPosts.firstIndex(where: { $0.id == post.id })
        
        // Optimistic update
        if let index = originalIndex {
            posts[index].isFavourited.toggle()
            posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
        }
        if let topIndex = originalTopIndex {
            topPosts[topIndex].isFavourited.toggle()
            topPosts[topIndex].favouritesCount += topPosts[topIndex].isFavourited ? 1 : -1
        }
        
        updateLoadingState(for: post.id, isLoading: true)
        Task {
            defer { self.updateLoadingState(for: post.id, isLoading: false) }
            do {
                // Pass the original favourited state (before optimistic update)
                let returnedPost = try await self.postActionService.toggleLike(postID: post.id, isCurrentlyFavourited: originalPost.isFavourited)
                
                // If API returns the updated post, use its state for consistency
                if let returnedPost = returnedPost {
                    if let index = self.posts.firstIndex(where: { $0.id == returnedPost.id }) {
                        self.posts[index].isFavourited = returnedPost.isFavourited
                        self.posts[index].favouritesCount = returnedPost.favouritesCount
                    }
                    if let topIndex = self.topPosts.firstIndex(where: { $0.id == returnedPost.id }) {
                        self.topPosts[topIndex].isFavourited = returnedPost.isFavourited
                        self.topPosts[topIndex].favouritesCount = returnedPost.favouritesCount
                    }
                }
            } catch {
                self.logger.error("Failed toggleLike network call: \(error.localizedDescription)")
                // Revert optimistic update if network call failed
                if let index = originalIndex {
                    self.posts[index].isFavourited = originalPost.isFavourited
                    self.posts[index].favouritesCount = originalPost.favouritesCount
                }
                if let topIndex = originalTopIndex {
                    self.topPosts[topIndex].isFavourited = originalPost.isFavourited
                    self.topPosts[topIndex].favouritesCount = originalPost.favouritesCount
                }
                self.alertError = AppError(message: "Failed to like post", underlyingError: error)
            }
        }
    }
    
    // Apply similar changes to toggleRepost
    func toggleRepost(for post: Post) {
        let originalPost = post
        let originalIndex = posts.firstIndex(where: { $0.id == post.id })
        let originalTopIndex = topPosts.firstIndex(where: { $0.id == post.id })
        
        // Optimistic update
        if let index = originalIndex {
            posts[index].isReblogged.toggle()
            posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
        }
        if let topIndex = originalTopIndex {
            topPosts[topIndex].isReblogged.toggle()
            topPosts[topIndex].reblogsCount += topPosts[topIndex].isReblogged ? 1 : -1
        }
        
        updateLoadingState(for: post.id, isLoading: true)
        Task {
            defer { self.updateLoadingState(for: post.id, isLoading: false) }
            do {
                let returnedPost = try await self.postActionService.toggleRepost(postID: post.id, isCurrentlyReblogged: originalPost.isReblogged)
                if let returnedPost = returnedPost {
                    if let index = self.posts.firstIndex(where: { $0.id == returnedPost.id }) {
                        self.posts[index].isReblogged = returnedPost.isReblogged
                        self.posts[index].reblogsCount = returnedPost.reblogsCount
                    }
                    if let topIndex = self.topPosts.firstIndex(where: { $0.id == returnedPost.id }) {
                        self.topPosts[topIndex].isReblogged = returnedPost.isReblogged
                        self.topPosts[topIndex].reblogsCount = returnedPost.reblogsCount
                    }
                }
            } catch {
                self.logger.error("Failed toggleRepost network call: \(error.localizedDescription)")
                // Revert optimistic update
                if let index = originalIndex {
                    self.posts[index].isReblogged = originalPost.isReblogged
                    self.posts[index].reblogsCount = originalPost.reblogsCount
                }
                if let topIndex = originalTopIndex {
                    self.topPosts[topIndex].isReblogged = originalPost.isReblogged
                    self.topPosts[topIndex].reblogsCount = originalPost.reblogsCount
                }
                self.alertError = AppError(message: "Failed to repost", underlyingError: error)
            }
        }
    }
    
    func comment(on post: Post, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        updateLoadingState(for: post.id, isLoading: true)
        Task {
            // [weak self] in // Optional
            defer { self.updateLoadingState(for: post.id, isLoading: false) } // Use self.
            // guard let self = self else { return } // Uncomment if using [weak self]
            do {
                // FIX: Assign result to _ to silence warning
                _ = try await self.postActionService.comment(postID: post.id, content: content) // Use self.
                // Optimistic Update counts
                // Use self. here
                if let index = self.posts.firstIndex(where: { $0.id == post.id }) { self.posts[index].repliesCount += 1 }
                if let topIndex = self.topPosts.firstIndex(where: { $0.id == post.id }) { self.topPosts[topIndex].repliesCount += 1 }
                
                // Use self. here
                self.commentText = ""
                self.showingCommentSheet = false
                self.selectedPostForComments = nil
                self.logger.info("Commented on post \(post.id)")
            } catch {
                // Use self. here
                self.logger.error("Failed to comment on post \(post.id): \(error.localizedDescription)")
                self.alertError = AppError(message: "Failed to post comment", underlyingError: error)
            }
        }
    }
    
    // --- Show Comment Sheet ---
    func showComments(for post: Post) {
        selectedPostForComments = post
        showingCommentSheet = true
    }
    
    
    // MARK: - Loading State Helper
    private func initializeLoadingStates(for newPosts: [Post]) {
        // No need for self. here as it's not in a closure
        var newStates = postLoadingStates
        for post in newPosts where newStates[post.id] == nil {
            newStates[post.id] = false
        }
        postLoadingStates = newStates
    }
    
    func isLoading(for post: Post) -> Bool {
        // No need for self. here
        return postLoadingStates[post.id] ?? false
    }
    
    private func updateLoadingState(for postId: String, isLoading: Bool) {
        // No need for self. here
        postLoadingStates[postId] = isLoading
    }
    
    // MARK: - Navigation
    func navigateToProfile(_ user: User) {
        // No need for self. here
        navigationPath.append(user)
    }
    
    func navigateToDetail(for post: Post) {
        // No need for self. here
        navigationPath.append(post)
    }
}
