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
    @StateObject private var viewModel = SearchViewModel() // Owns search logic and state

    // Focus State
    @FocusState private var isSearchFieldFocused: Bool

    // Local State for Sheet Presentation
    @State private var showSearchFilters = false
    @State private var selectedPostForDetail: Post? = nil // Use local state for detail view presentation
    @State private var selectedHashtagForAnalytics: Tag? = nil // Use local state for analytics sheet

    // Navigation Path (if navigating from search results)
    // Consider if navigation should be handled by a higher-level coordinator or TabView
    @State private var navigationPath = NavigationPath()


    var body: some View {
        // Use NavigationStack for potential drill-down navigation
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) { // Use spacing 0 for tighter control
                // --- Search Bar Area ---
                searchBarArea
                    .padding(.bottom, 8)

                // --- Category Picker ---
                categoryPicker
                    .padding(.bottom, 8)

                // --- Results List ---
                searchResultsList
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Toolbar items
                ToolbarItem(placement: .navigationBarTrailing) { filterButton }
                ToolbarItem(placement: .keyboard) { keyboardDoneButton }
            }
             // --- Sheets ---
            .sheet(isPresented: $showSearchFilters) { filtersSheet } // Filters
            .sheet(item: $selectedHashtagForAnalytics) { tag in analyticsSheet(tag: tag) } // Analytics
            .sheet(item: $selectedPostForDetail) { post in detailSheet(post: post) } // Post Detail

             // --- Initial Data Load ---
            .task { // Use .task for async operations on appear
                // Load trending hashtags when the view first appears
                if viewModel.trendingHashtags.isEmpty {
                    await viewModel.loadTrendingHashtags()
                }
            }
             // --- Error Alert ---
            .alert(item: $viewModel.error) { error in
                 Alert(title: Text("Error"), message: Text(error.localizedDescription), dismissButton: .default(Text("OK")))
            }
             // --- Navigation ---
            .navigationDestination(for: User.self) { user in // Profile Navigation
                 ProfileView(user: user)
                     // Pass necessary environment objects
                     .environmentObject(timelineViewModel)
                     // Assuming ProfileView needs these:
                     // .environmentObject(AuthViewModel_Instance)
                     // .environmentObject(ProfileViewModel_Instance)
            }
        }
    }

    // MARK: - Search Bar Area Components
    private var searchBarArea: some View {
        VStack(spacing: 5) {
            SearchBar(text: $viewModel.searchText, isFocused: $isSearchFieldFocused)
                .padding(.horizontal)

            // Conditional Cancel Button
            if !viewModel.searchText.isEmpty || isSearchFieldFocused {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.searchText = "" // Clear text
                        viewModel.clearSearch() // Clear results
                        isSearchFieldFocused = false // Dismiss keyboard
                    }
                    .padding(.trailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity)) // Add fade
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.searchText.isEmpty && !isSearchFieldFocused) // Animate appearance
            }
        }
    }

    // MARK: - Category Picker
    private var categoryPicker: some View {
        Picker("Search Category", selection: $viewModel.selectedCategory) {
            ForEach(SearchViewModel.SearchCategory.allCases) { category in
                Text(category.rawValue).tag(category)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: viewModel.selectedCategory) { _, _ in // Use new onChange syntax
             // Trigger search immediately when category changes
             // Debouncing on searchText handles rapid typing
            Task {
                await viewModel.search(query: viewModel.searchText)
            }
        }
    }

    // MARK: - Results List
    @ViewBuilder
    private var searchResultsList: some View {
        if viewModel.isLoading && viewModel.searchResults.accounts.isEmpty && viewModel.searchResults.statuses.isEmpty && viewModel.searchResults.hashtags.isEmpty {
             // Show loading indicator only when loading initial results
            Spacer() // Pushes ProgressView to center
            ProgressView("Searching...")
            Spacer()
        } else {
            List {
                // Display content based on the selected category
                switch viewModel.selectedCategory {
                case .all:      combinedResultsSections
                case .accounts: accountResultsSection
                case .posts:    postResultsSection
                case .hashtags: hashtagResultsSection
                case .trending: trendingHashtagsSection
                }
            }
            .listStyle(.plain) // Use plain style for less visual clutter
            .overlay { // Show message if search is empty and not loading
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

    // Computed property to check if relevant sections are empty
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
            return viewModel.trendingHashtags.isEmpty // Check trending separately
        }
    }


    // MARK: - List Section Views
    private var combinedResultsSections: some View {
        Group {
            // Conditionally show sections only if they have content
            if !viewModel.searchResults.accounts.isEmpty { accountSection }
            if !viewModel.searchResults.statuses.isEmpty { postSection }
            if !viewModel.searchResults.hashtags.isEmpty { hashtagSection }
        }
    }

    private var accountSection: some View {
        Section(header: Text("Accounts").font(.headline)) { // Use prominent header
            // Use viewModel.searchResults
            ForEach(viewModel.searchResults.accounts) { account in
                // Navigate using value type User
                NavigationLink(value: account.toUser()) {
                    AccountRow(account: account) // Assuming AccountRow exists
                }
            }
        }
    }

    private var postSection: some View {
        Section(header: Text("Posts").font(.headline)) {
            ForEach(viewModel.searchResults.statuses) { post in
                 // Use the revised PostView
                PostView(
                    post: post,
                    viewModel: timelineViewModel, // Pass timelineViewModel for actions
                    viewProfileAction: { user in
                         navigationPath.append(user) // Navigate on profile tap
                    }
                )
                .contentShape(Rectangle()) // Make whole area tappable
                .onTapGesture {
                     selectedPostForDetail = post // Show detail view on tap
                }
                .listRowInsets(EdgeInsets()) // Remove default padding for custom PostView layout
                .padding(.vertical, 5) // Add vertical padding between posts
            }
        }
    }

    private var hashtagSection: some View {
        Section(header: Text("Hashtags").font(.headline)) {
            ForEach(viewModel.searchResults.hashtags, id: \.name) { hashtag in // Use name as ID if Tag isn't Identifiable
                HStack {
                    Text("#\(hashtag.name)")
                        .foregroundColor(.blue) // Style hashtags
                    Spacer()
                    // Optionally show usage count if available (API v1 doesn't provide it here)
                    Image(systemName: "chart.line.uptrend.xyaxis") // Indicate analytics available
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle()) // Make whole row tappable
                .onTapGesture {
                    selectedHashtagForAnalytics = hashtag // Show analytics sheet
                }
            }
        }
    }

    // Specific sections for filtered views
    private var accountResultsSection: some View {
        // Contents are the same as accountSection, just shown alone
        ForEach(viewModel.searchResults.accounts) { account in
             NavigationLink(value: account.toUser()) {
                 AccountRow(account: account)
             }
        }
    }

    private var postResultsSection: some View {
         // Contents are the same as postSection, just shown alone
         ForEach(viewModel.searchResults.statuses) { post in
             PostView(post: post, viewModel: timelineViewModel, viewProfileAction: { user in navigationPath.append(user) })
                 .contentShape(Rectangle())
                 .onTapGesture { selectedPostForDetail = post }
                 .listRowInsets(EdgeInsets())
                 .padding(.vertical, 5)
         }
    }

    private var hashtagResultsSection: some View {
         // Contents are the same as hashtagSection, just shown alone
         ForEach(viewModel.searchResults.hashtags, id: \.name) { hashtag in
             HStack {
                 Text("#\(hashtag.name)").foregroundColor(.blue)
                 Spacer()
                 Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.gray)
             }
             .contentShape(Rectangle())
             .onTapGesture { selectedHashtagForAnalytics = hashtag }
         }
    }


    // Section for Trending Hashtags
    private var trendingHashtagsSection: some View {
        Section(header: Text("Trending Today").font(.headline)) {
            // Use viewModel.trendingHashtags
            ForEach(viewModel.trendingHashtags, id: \.name) { hashtag in // Use name as ID
                 HStack {
                     Text("#\(hashtag.name)").foregroundColor(.blue)
                     Spacer()
                     // Optionally show history graph icon if history data exists
                     if hashtag.history?.isEmpty == false {
                          Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.gray)
                     }
                 }
                 .contentShape(Rectangle())
                 .onTapGesture {
                     selectedHashtagForAnalytics = hashtag // Show analytics sheet
                 }
            }
        }
    }

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
        // Assuming SearchFiltersView exists and takes a binding
        NavigationView { // Add NavigationView for title/buttons
            SearchFiltersView(filters: $viewModel.searchFilters) {
                 // Apply filters logic (triggers a new search)
                 Task { await viewModel.search(query: viewModel.searchText) }
                 showSearchFilters = false // Dismiss sheet
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
         // Assuming HashtagAnalyticsView exists
         // Pass necessary data and bindings
         HashtagAnalyticsView(
             hashtag: tag.name,
             // Map History? to TagHistory if needed, or ensure models match
             history: tag.history?.compactMap { TagHistory(day: $0.day, uses: $0.uses, accounts: $0.accounts) } ?? [],
             selectedTimeRange: $viewModel.selectedTimeRange,
             showHashtagAnalytics: Binding( // Create binding to dismiss sheet
                 get: { selectedHashtagForAnalytics != nil },
                 set: { if !$0 { selectedHashtagForAnalytics = nil } }
             ),
             viewModel: viewModel // Pass the SearchViewModel
         )
         .environmentObject(timelineViewModel) // Pass TimelineViewModel if needed
    }

     private func detailSheet(post: Post) -> some View {
         // Assuming PostDetailView exists
         // Pass the post and necessary view models
         PostDetailView(
             post: post,
             viewModel: timelineViewModel, // Pass timelineViewModel for actions
             showDetail: Binding( // Create binding to dismiss sheet
                 get: { selectedPostForDetail != nil },
                 set: { if !$0 { selectedPostForDetail = nil } }
             )
         )
         // Pass other environment objects if PostDetailView needs them
         // .environmentObject(AuthViewModel_Instance)
         // .environmentObject(ProfileViewModel_Instance)
     }
}


// MARK: - Placeholder Views (Ensure these exist)

// Placeholder for SearchFiltersView. Create a real view for your filters.
struct SearchFiltersView: View {
    @Binding var filters: SearchViewModel.SearchFilters
    var onApply: () -> Void // Closure to apply filters

    // Environment for dismissing the sheet
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // Replace with your actual filter UI elements
        Form {
             Section("General") {
                 Toggle("Include Full Profile Data (Resolve)", isOn: Binding(
                     get: { filters.resolve ?? true }, // Default to true
                     set: { filters.resolve = $0 }
                 ))
                 Toggle("Exclude Unreviewed Content", isOn: Binding(
                      get: { filters.excludeUnreviewed ?? false }, // Default to false
                      set: { filters.excludeUnreviewed = $0 }
                 ))
             }
             Section("Pagination / ID") {
                  TextField("Max Status ID", text: Binding(
                      get: { filters.maxId ?? "" },
                      set: { filters.maxId = $0.isEmpty ? nil : $0 }
                  ))
                  .keyboardType(.numberPad)

                 TextField("Min Status ID", text: Binding(
                      get: { filters.minId ?? "" },
                      set: { filters.minId = $0.isEmpty ? nil : $0 }
                  ))
                  .keyboardType(.numberPad)

                 Stepper("Limit: \(filters.limit ?? 20)", value: Binding(
                     get: { filters.limit ?? 20 },
                     set: { filters.limit = $0 }
                 ), in: 5...40, step: 5) // Limit between 5 and 40
             }
             // Add more filter options as needed (e.g., following, accountId)
         }
         // No need for explicit Apply button if using toolbar in SearchView
         // .navigationBarItems(...) // Handled in SearchView's sheet modifier
    }
}
