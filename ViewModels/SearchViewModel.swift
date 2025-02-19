//
//  SearchViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchResults: SearchResults = SearchResults(accounts: [], statuses: [], hashtags: [])
    @Published var trendingHashtags: [Tag] = []
    @Published var selectedCategory: SearchCategory = .all
    @Published var selectedTimeRange: TimeRange = .day  //For Hashtag Analytics  //Corrected: Use the enum from SearchViewModel
    @Published var showHashtagAnalytics = false //For Hashtag Analytics
    @Published var searchFilters: SearchFilters = SearchFilters() // Corrected:  Instantiate the struct.
    @Published var error: IdentifiableError? // Use the custom IdentifiableError
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()

    enum SearchCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case accounts = "Accounts"
        case posts = "Posts"
        case hashtags = "Hashtags"
        case trending = "Trending"

        var id: String { self.rawValue }
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "1 Day"
        case week = "7 Days"
        case month = "1 Month"
        case year = "1 Year"
        var id: String { self.rawValue }
    }
    
    // Custom Identifiable Error type
    struct IdentifiableError: Identifiable, Error {
        let id = UUID()
        let message: String
            
        var localizedDescription: String { message } // Provide localizedDescription
    }

    //Add SearchFilter Struct
    struct SearchFilters {
        var limit: Int? = nil
        var resolve: Bool? = nil
        var following: Bool? = nil
        var excludeUnreviewed: Bool? = nil
        var accountId: String? = nil
        var maxId: String? = nil
        var minId: String? = nil
        var offset: Int? = nil
        var selectedHashtag: String? = nil // Add this for hashtag analytics
    }


    init(searchService: SearchService = SearchService(networkService: NetworkService.shared)) {
        self.searchService = searchService
    }

    @MainActor
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = SearchResults(accounts: [], statuses: [], hashtags: [])
            return
        }
        
        // Determine the search type based on selectedCategory
        let type: String?
        switch selectedCategory {
        case .all:
            type = nil // No type parameter means search all
        case .accounts:
            type = "accounts"
        case .posts:
            type = "statuses"
        case .hashtags:
            type = "hashtags"
        case .trending:
            type = nil  //Should use different API for trends
        }

        do {
            let results = try await searchService.search(
                query: query,
                type: type,
                // Safely unwrap optionals using nil coalescing
                limit: searchFilters.limit ?? 20,  // Provide default values
                resolve: searchFilters.resolve ?? false,
                excludeUnreviewed: searchFilters.excludeUnreviewed ?? false
            )
            self.searchResults = results
        } catch {
            self.error = IdentifiableError(message: error.localizedDescription) // Wrap in IdentifiableError
            print("Search error: \(error)")
            self.searchResults = SearchResults(accounts: [], statuses: [], hashtags: [])
        }
    }

    @MainActor
    func loadTrendingHashtags() async {
        do {
            trendingHashtags = try await searchService.fetchTrendingHashtags()
        } catch {
            self.error = IdentifiableError(message: error.localizedDescription) // Wrap in IdentifiableError

            print("Error loading trending hashtags: \(error)")
        }
    }
}
