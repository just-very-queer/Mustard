//
//  SearchViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
// (REVISED & FIXED)

import SwiftUI
import Combine
import OSLog

// MARK: - SearchResults Definition
struct SearchResults: Decodable {
    var accounts: [Account] = []
    var statuses: [Post] = []
    var hashtags: [Tag] = []
}

@MainActor
class SearchViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published private(set) var searchResults: SearchResults = SearchResults()
    @Published private(set) var trendingHashtags: [Tag] = []
    @Published var selectedCategory: SearchCategory = .all
    @Published var selectedTimeRange: TimeRange = .day
    @Published var showHashtagAnalytics = false
    @Published var searchFilters: SearchFilters = SearchFilters()
    @Published var error: IdentifiableError?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var filteredPosts: [Post] = []

    // MARK: - Services and Private Properties
    private let searchService: SearchService
    private var searchTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "SearchViewModel")

    // MARK: - Enums
    enum SearchCategory: String, CaseIterable, Identifiable {
        case all = "All", accounts = "Accounts", posts = "Posts", hashtags = "Hashtags", trending = "Trending"
        var id: String { self.rawValue }
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "1 Day", week = "7 Days", month = "1 Month", year = "1 Year"
        var id: String { self.rawValue }
    }

    // MARK: - Helper Structs
    struct IdentifiableError: Identifiable, Error {
        let id = UUID()
        let message: String
        var localizedDescription: String { message }
    }

    struct SearchFilters {
        var limit: Int? = 20
        var resolve: Bool? = true
        var excludeUnreviewed: Bool? = false
        var accountId: String? = nil
        var maxId: String? = nil
        var minId: String? = nil
        var offset: Int? = nil
    }

    // MARK: - Initialization
    // ***** FIXED: Use NetworkService.shared instance *****
    init(searchService: SearchService = SearchService) {
        self.searchService = searchService
        setupDebounce()
    }

    // MARK: - Debouncing Logic
    private func setupDebounce() {
        $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] currentQuery in
                self?.searchTask?.cancel()
                self?.searchTask = Task {
                    if Task.isCancelled { return }
                    await self?.search(query: currentQuery)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Execution
    func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            logger.info("Search query is empty, clearing results.")
            self.searchResults = SearchResults()
            self.isLoading = false
            return
        }

        logger.debug("Starting search for query: '\(trimmedQuery)'")
        self.isLoading = true
        self.error = nil

        do {
            guard !Task.isCancelled else {
                logger.info("Search task cancelled for query: '\(trimmedQuery)'")
                self.isLoading = false
                return
            }

            let results = try await searchService.search(
                query: trimmedQuery,
                type: searchApiTypeParameter,
                limit: searchFilters.limit ?? 20,
                resolve: searchFilters.resolve ?? true,
                excludeUnreviewed: searchFilters.excludeUnreviewed ?? false,
                accountId: searchFilters.accountId,
                maxId: searchFilters.maxId,
                minId: searchFilters.minId,
                offset: searchFilters.offset
            )

            guard !Task.isCancelled else {
                logger.info("Search task cancelled after fetch for query: '\(trimmedQuery)'")
                self.isLoading = false
                return
            }

            logger.debug("Search successful for query: '\(trimmedQuery)'. Found \(results.accounts.count) accounts, \(results.statuses.count) posts, \(results.hashtags.count) hashtags.")
            self.searchResults = results

        } catch let fetchError where (fetchError as? URLError)?.code == .cancelled {
             logger.info("Search explicitly cancelled for query: '\(trimmedQuery)'.")
             // No need to set isLoading = false here, as it might have been set by the defer in a surrounding task
        } catch let fetchError {
             guard !Task.isCancelled else {
                 logger.info("Search task cancelled during error handling for query: '\(trimmedQuery)'")
                 // No need to set isLoading = false here either
                 return
             }
            logger.error("Search failed for query '\(trimmedQuery)': \(fetchError.localizedDescription)")
            self.error = IdentifiableError(message: "Search failed: \(fetchError.localizedDescription)")
            self.searchResults = SearchResults()
        }

         // Ensure loading is always set to false eventually if the task wasn't cancelled
         if !Task.isCancelled {
             self.isLoading = false
         }
    }

    private var searchApiTypeParameter: String? {
        switch selectedCategory {
        case .all: return nil
        case .accounts: return "accounts"
        case .posts: return "statuses"
        case .hashtags: return "hashtags"
        case .trending: return nil
        }
    }

    // MARK: - Trending Hashtags
    func loadTrendingHashtags() async {
        logger.info("Loading trending hashtags...")
        self.isLoading = true
        self.error = nil

        do {
            trendingHashtags = try await searchService.fetchTrendingHashtags()
            logger.info("Loaded \(self.trendingHashtags.count) trending hashtags.")
        } catch let fetchError {
            logger.error("Failed to load trending hashtags: \(fetchError.localizedDescription)")
            self.error = IdentifiableError(message: "Could not load trending tags: \(fetchError.localizedDescription)")
            // ***** FIXED: Added self. *****
            self.trendingHashtags = []
        }
        self.isLoading = false
    }

    // MARK: - Hashtag Analytics Posts
    func filterPostsForHashtag(_ hashtag: String, timeRange: TimeRange) {
        Task {
            await fetchAndFilterPosts(for: hashtag, timeRange: timeRange)
        }
    }

    private func fetchAndFilterPosts(for hashtag: String, timeRange: TimeRange) async {
        logger.debug("Fetching posts for hashtag '\(hashtag)' within time range \(timeRange.rawValue)...")
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let posts = try await searchService.fetchHashtagPosts(hashtag: hashtag)
            logger.debug("Fetched \(posts.count) posts for hashtag '\(hashtag)'. Filtering by time...")

            let now = Date()
            let calendar = Calendar.current
            var startDate: Date

            switch timeRange {
            case .day: startDate = calendar.date(byAdding: .day, value: -1, to: now)!
            case .week: startDate = calendar.date(byAdding: .day, value: -7, to: now)!
            case .month: startDate = calendar.date(byAdding: .month, value: -1, to: now)!
            case .year: startDate = calendar.date(byAdding: .year, value: -1, to: now)!
            }

            // Filter the results
            // ***** FIXED: Added self. *****
            self.filteredPosts = posts.filter { post in
                post.createdAt >= startDate
             }
             logger.debug("Filtered down to \(self.filteredPosts.count) posts for hashtag '\(hashtag)' in the last \(timeRange.rawValue).") // Use self here too for consistency
        } catch let fetchError {
            logger.error("Failed to fetch/filter posts for hashtag '\(hashtag)': \(fetchError.localizedDescription)")
            self.error = IdentifiableError(message: "Failed to load posts for hashtag: \(fetchError.localizedDescription)")
            self.filteredPosts = [] // Also use self. here
        }
    }

    // MARK: - Clearing Search
    func clearSearch() {
        logger.info("Clearing search results.")
        searchResults = SearchResults()
    }
}
