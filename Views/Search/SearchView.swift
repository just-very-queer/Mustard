//
//  SearchView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
// (REVISED)

import SwiftUI
import Combine

struct SearchView: View {
    // Environment Objects
    @EnvironmentObject var timelineViewModel: TimelineViewModel // For Post actions and navigation context

    // State Objects
    // FIX 1: Correctly initialize SearchService with the MastodonAPIService instance
    @StateObject private var viewModel = SearchViewModel(searchService: SearchService(mastodonAPIService: MustardApp.mastodonAPIServiceInstance)) // Owns search logic and state

    // Focus State
    @FocusState private var isSearchFieldFocused: Bool

    // Local State for Sheet Presentation
    @State private var showSearchFilters = false
    @State private var selectedPostForDetail: Post? = nil
    @State private var selectedHashtagForAnalytics: Tag? = nil

    @State private var navigationPath = NavigationPath()


    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                searchBarArea
                    .padding(.bottom, 8)

                categoryPicker
                    .padding(.bottom, 8)

                searchResultsList
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { filterButton }
                ToolbarItem(placement: .keyboard) { keyboardDoneButton }
            }
            .sheet(isPresented: $showSearchFilters) { filtersSheet }
            .sheet(item: $selectedHashtagForAnalytics) { tag in analyticsSheet(tag: tag) }
            .sheet(item: $selectedPostForDetail) { post in detailSheet(post: post) }
            .task {
                if viewModel.trendingHashtags.isEmpty {
                    await viewModel.loadTrendingHashtags()
                }
            }
            // FIX 2: Use errorContent.message in the alert
            .alert(item: $viewModel.error) { errorContent in
                 Alert(title: Text("Error"), message: Text(errorContent.message), dismissButton: .default(Text("OK")))
            }
            .navigationDestination(for: User.self) { user in
                 ProfileView(user: user)
                     .environmentObject(timelineViewModel)
            }
        }
    }

    // MARK: - Search Bar Area Components
    private var searchBarArea: some View {
        VStack(spacing: 5) {
            SearchBar(text: $viewModel.searchText, isFocused: $isSearchFieldFocused)
                .padding(.horizontal)

            if !viewModel.searchText.isEmpty || isSearchFieldFocused {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.searchText = ""
                        viewModel.clearSearch()
                        isSearchFieldFocused = false
                    }
                    .padding(.trailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.searchText.isEmpty && !isSearchFieldFocused)
            }
        }
    }

    // MARK: - Category Picker
    private var categoryPicker: some View {
        // FIX 3: This should resolve once ViewModel initialization is correct.
        Picker("Search Category", selection: $viewModel.selectedCategory) {
            ForEach(SearchViewModel.SearchCategory.allCases) { category in
                Text(category.rawValue).tag(category)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: viewModel.selectedCategory) { _, _ in
            Task {
                await viewModel.search(query: viewModel.searchText)
            }
        }
    }

    // MARK: - Results List
    @ViewBuilder
    private var searchResultsList: some View {
        if viewModel.isLoading && viewModel.searchResults.accounts.isEmpty && viewModel.searchResults.statuses.isEmpty && viewModel.searchResults.hashtags.isEmpty {
            Spacer()
            ProgressView("Searching...")
            Spacer()
        } else {
            List {
                switch viewModel.selectedCategory {
                case .all:      combinedResultsSections
                case .accounts: accountResultsSection
                case .posts:    postResultsSection
                case .hashtags: hashtagResultsSection
                case .trending: trendingHashtagsSection
                }
            }
            .listStyle(.plain)
            .overlay {
                 if !viewModel.isLoading && viewModel.searchText.isEmpty && viewModel.selectedCategory != .trending {
                     Text("Enter a query to search.")
                         .foregroundColor(.gray)
                 } else if !viewModel.isLoading && !viewModel.searchText.isEmpty && sectionsAreEmpty {
                      Text("No results found for \"\(viewModel.searchText)\".")
                         .foregroundColor(.gray)
                 }
            }
        }
    }

    private var sectionsAreEmpty: Bool {
        switch viewModel.selectedCategory {
        case .all:
            return viewModel.searchResults.accounts.isEmpty && viewModel.searchResults.statuses.isEmpty && viewModel.searchResults.hashtags.isEmpty
        case .accounts:
            return viewModel.searchResults.accounts.isEmpty
        case .posts:
            return viewModel.searchResults.statuses.isEmpty
        case .hashtags:
            return viewModel.searchResults.hashtags.isEmpty
        case .trending:
            return viewModel.trendingHashtags.isEmpty
        }
    }


    // MARK: - List Section Views (Now using extracted components)
    // The computed properties for sections are removed.
    // Their logic is now within AccountSectionView, PostSectionView, HashtagSectionView, TrendingHashtagsSectionView.

    // MARK: - Toolbar Buttons
    private var filterButton: some View {
        Button { showSearchFilters.toggle() } label: {
            Image(systemName: "slider.horizontal.3")
                .accessibilityLabel("Search Filters")
        }
    }

    private var keyboardDoneButton: some View {
         HStack {
            Spacer()
            Button("Done") { isSearchFieldFocused = false }
        }
    }

    // MARK: - Sheet Views
    private var filtersSheet: some View {
        NavigationView {
            SearchFiltersView(filters: $viewModel.searchFilters) {
                 Task { await viewModel.search(query: viewModel.searchText) }
                 showSearchFilters = false
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showSearchFilters = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                         Task { await viewModel.search(query: viewModel.searchText) }
                         showSearchFilters = false
                    }
                }
            }
        }
    }

    private func analyticsSheet(tag: Tag) -> some View {
         HashtagAnalyticsView(
             hashtag: tag.name,
             history: tag.history?.compactMap { TagHistory(day: $0.day, uses: $0.uses, accounts: $0.accounts) } ?? [],
             selectedTimeRange: $viewModel.selectedTimeRange,
             showHashtagAnalytics: Binding(
                 get: { selectedHashtagForAnalytics != nil },
                 set: { if !$0 { selectedHashtagForAnalytics = nil } }
             ),
             viewModel: viewModel
         )
         .environmentObject(timelineViewModel)
    }

     private func detailSheet(post: Post) -> some View {
         PostDetailView(
             post: post,
             viewModel: timelineViewModel,
             showDetail: Binding(
                 get: { selectedPostForDetail != nil },
                 set: { if !$0 { selectedPostForDetail = nil } }
             )
         )
     }
}

// SearchFiltersView struct has been moved to Views/Search/Components/SearchFiltersView.swift
// AccountSectionView, PostSectionView, HashtagSectionView, TrendingHashtagsSectionView
// are now defined in their respective files in Views/Search/Components/
