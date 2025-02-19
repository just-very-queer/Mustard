//
//  SearchView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var showSearchFilters = false
    @FocusState private var isSearchFieldFocused: Bool  // Corrected: No change needed here
    @State private var selectedPost: Post? = nil
    @State private var showPostDetail = false

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, isFocused: $isSearchFieldFocused)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .onChange(of: searchText) { _, newValue in
                        Task { await viewModel.search(query: newValue) }
                    }

                Picker("Search Category", selection: $viewModel.selectedCategory) {
                    ForEach(SearchViewModel.SearchCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.selectedCategory) { _, _ in
                    Task { await viewModel.search(query: searchText) }
                }

                List {
                    switch viewModel.selectedCategory {
                    case .all: combinedResultsSection
                    case .accounts: accountResultsSection
                    case .posts: postResultsSection
                    case .hashtags: hashtagResultsSection
                    case .trending: trendingHashtagsSection
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showSearchFilters.toggle() } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Spacer()
                            Button("Done") { isSearchFieldFocused = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearchFilters) {
                // Assuming you have a SearchFiltersView defined elsewhere
                SearchFiltersView(filters: $viewModel.searchFilters) {
                    Task { await viewModel.search(query: searchText) }
                }
            }
            .overlay(postDetailOverlay)
            .task { await viewModel.loadTrendingHashtags() }
            .alert("Error", isPresented: $viewModel.showError) {
                // Optionally add alert buttons here.
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var postDetailOverlay: some View {
        Group {
            if let post = selectedPost, showPostDetail {
                PostDetailView(
                    post: post,
                    viewModel: timelineViewModel,
                    showDetail: $showPostDetail
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
    }
    
    // MARK: - List Sections
    private var combinedResultsSection: some View {
        Group {
            accountSection
            postSection
            hashtagSection
        }
    }
    
    private var accountSection: some View {
        Section(header: Text("Accounts")) {
            ForEach(viewModel.searchResults.accounts) { account in
                NavigationLink(destination: ProfileView(user: account.toUser())) {
                    // Assuming you have an AccountRow view
                    AccountRow(account: account)
                }
            }
        }
    }
    
    private var postSection: some View {
        Section(header: Text("Posts")) {
            ForEach(viewModel.searchResults.statuses) { post in
                PostRow(post: post, viewModel: timelineViewModel)
                    .onTapGesture {
                        withAnimation {
                            selectedPost = post
                            showPostDetail = true
                        }
                    }
            }
        }
    }
    
    private var hashtagSection: some View {
        Section(header: Text("Hashtags")) {
            ForEach(viewModel.searchResults.hashtags, id: \.name) { hashtag in
                Text("#\(hashtag.name)")
                    .onTapGesture {
                        viewModel.searchFilters.selectedHashtag = hashtag.name
                        viewModel.showHashtagAnalytics = true
                    }
            }
        }
    }
    
    private var accountResultsSection: some View {
        ForEach(viewModel.searchResults.accounts) { account in
            NavigationLink(destination: ProfileView(user: account.toUser())) {
                // Assuming you have an AccountRow view
                AccountRow(account: account)
            }
        }
    }
    
    private var postResultsSection: some View {
        ForEach(viewModel.searchResults.statuses) { post in
            PostRow(post: post, viewModel: timelineViewModel)
                .onTapGesture {
                    withAnimation {
                        selectedPost = post
                        showPostDetail = true
                    }
                }
        }
    }
    
    private var hashtagResultsSection: some View {
        ForEach(viewModel.searchResults.hashtags, id: \.name) { hashtag in
            Text("#\(hashtag.name)")
                .onTapGesture {
                    viewModel.searchFilters.selectedHashtag = hashtag.name
                    viewModel.showHashtagAnalytics = true
                }
        }
    }
    
    private var trendingHashtagsSection: some View {
        ForEach(viewModel.trendingHashtags, id: \.name) { hashtag in
            Text("#\(hashtag.name)")
                .onTapGesture {
                    viewModel.searchFilters.selectedHashtag = hashtag.name
                    viewModel.showHashtagAnalytics = true
                }
        }
    }
}

// MARK: - Placeholder Views (Replace with your actual implementations)

// Placeholder for AccountRow.  Create a real view for displaying accounts.
struct AccountRow: View {
    let account: Account
    var body: some View {
        Text(account.display_name ?? "Unknown Account") // Replace with your actual AccountRow layout
    }
}

// Placeholder for SearchFiltersView. Create a real view for your filters.
struct SearchFiltersView: View {
    @Binding var filters: SearchViewModel.SearchFilters
    var onApply: () -> Void
    
    var body: some View {
        Text("Search Filters Go Here") // Replace with your filter UI
            .onTapGesture {
                onApply()
            }
    }
}
