//
//  SearchView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
// (REVISED)

import SwiftUI
import Combine


struct SearchView: View {
    // MARK: - Environment
    @EnvironmentObject var timelineViewModel: TimelineViewModel // For Post actions and navigation context

    // MARK: - Services
    private let searchService = SearchService(mastodonAPIService: MustardApp.mastodonAPIServiceInstance)

    // MARK: - State
    @State private var searchText: String = ""
    @State private var searchResults: SearchResults = SearchResults()
    @State private var trendingHashtags: [Tag] = []
    @State private var selectedCategory: SearchCategory = .all
    @State private var searchFilters: SearchFilters = SearchFilters()
    @State private var error: IdentifiableError?
    @State private var isLoading: Bool = false

    @State private var searchTask: Task<Void, Never>?

    // Focus State
    @FocusState private var isSearchFieldFocused: Bool

    // Sheet Presentation State
    @State private var showSearchFilters = false
    @State private var selectedPostForDetail: Post? = nil
    @State private var selectedHashtagForAnalytics: Tag? = nil

    // Navigation
    @State private var navigationPath = NavigationPath()
    @State private var showGlow = false

    var body: some View {
        ZStack {
            if showGlow {
                GlowEffect()
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }

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
                triggerGlow()
                if trendingHashtags.isEmpty {
                    await loadTrendingHashtags()
                }
            }
            .alert(item: $error) { errorContent in
                 Alert(title: Text("Error"), message: Text(errorContent.message), dismissButton: .default(Text("OK")))
            }
            .navigationDestination(for: User.self) { user in
                 ProfileView(user: user)
                     .environmentObject(timelineViewModel)
            }
            .onChange(of: searchText) {
                searchTask?.cancel()
                searchTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(0.5))
                        await search(query: searchText)
                    } catch {
                        // Cancellation will throw an error, so we catch and return
                        return
                    }
                }
            }
        }
    }

    // MARK: - Search Bar Area
    private var searchBarArea: some View {
        VStack(spacing: 5) {
            SearchBar(text: $searchText, isFocused: $isSearchFieldFocused)
                .padding(.horizontal)

            if !searchText.isEmpty || isSearchFieldFocused {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        searchText = ""
                        clearSearch()
                        isSearchFieldFocused = false
                    }
                    .padding(.trailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty && !isSearchFieldFocused)
            }
        }
    }

    // MARK: - Category Picker
    private var categoryPicker: some View {
        Picker("Search Category", selection: $selectedCategory) {
            ForEach(SearchCategory.allCases) { category in
                Text(category.rawValue).tag(category)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: selectedCategory) {
            Task {
                await search(query: searchText)
            }
        }
    }

    // MARK: - Results List
    @ViewBuilder
    private var searchResultsList: some View {
        if isLoading && searchResults.accounts.isEmpty && searchResults.statuses.isEmpty && searchResults.hashtags.isEmpty {
            Spacer()
            ProgressView("Searching...")
            Spacer()
        } else {
            List {
                switch selectedCategory {
                case .all:      combinedResultsSections
                case .accounts: accountResultsSection
                case .posts:    postResultsSection
                case .hashtags: hashtagResultsSection
                case .trending: trendingHashtagsSection
                }
            }
            .listStyle(.plain)
            .overlay {
                 if !isLoading && searchText.isEmpty && selectedCategory != .trending {
                     Text("Enter a query to search.")
                         .foregroundColor(.gray)
                 } else if !isLoading && !searchText.isEmpty && sectionsAreEmpty {
                      Text("No results found for \"\(searchText)\".")
                         .foregroundColor(.gray)
                 }
            }
        }
    }

    private var sectionsAreEmpty: Bool {
        switch selectedCategory {
        case .all:
            return searchResults.accounts.isEmpty && searchResults.statuses.isEmpty && searchResults.hashtags.isEmpty
        case .accounts:
            return searchResults.accounts.isEmpty
        case .posts:
            return searchResults.statuses.isEmpty
        case .hashtags:
            return searchResults.hashtags.isEmpty
        case .trending:
            return trendingHashtags.isEmpty
        }
    }

    // MARK: - List Sections
    private var combinedResultsSections: some View {
        Group {
            if !searchResults.accounts.isEmpty { accountSection }
            if !searchResults.statuses.isEmpty { postSection }
            if !searchResults.hashtags.isEmpty { hashtagSection }
        }
    }

    private var accountSection: some View {
        Section(header: Text("Accounts").font(.headline)) {
            ForEach(searchResults.accounts) { account in
                NavigationLink(value: account.toUser()) {
                    AccountRow(account: account)
                }
            }
        }
    }

    private var postSection: some View {
        Section(header: Text("Posts").font(.headline)) {
            ForEach(searchResults.statuses) { post in
                PostView(
                    post: post,
                    viewProfileAction: { user in
                         navigationPath.append(user)
                    },
                    interestScore: 0.0
                )
                .contentShape(Rectangle())
                .onTapGesture {
                     selectedPostForDetail = post
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 5)
            }
        }
    }

    private var hashtagSection: some View {
        Section(header: Text("Hashtags").font(.headline)) {
            ForEach(searchResults.hashtags) { hashtag in
                HStack {
                    Text("#\(hashtag.name)")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedHashtagForAnalytics = hashtag
                }
            }
        }
    }

    private var accountResultsSection: some View {
        ForEach(searchResults.accounts) { account in
             NavigationLink(value: account.toUser()) {
                 AccountRow(account: account)
             }
        }
    }

    private var postResultsSection: some View {
         ForEach(searchResults.statuses) { post in
             PostView(
                post: post,
                viewProfileAction: { user in navigationPath.append(user) },
                interestScore: 0.0
             )
                 .contentShape(Rectangle())
                 .onTapGesture { selectedPostForDetail = post }
                 .listRowInsets(EdgeInsets())
                 .padding(.vertical, 5)
         }
    }

    private var hashtagResultsSection: some View {
         ForEach(searchResults.hashtags) { hashtag in
             HStack {
                 Text("#\(hashtag.name)").foregroundColor(.blue)
                 Spacer()
                 Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.gray)
             }
             .contentShape(Rectangle())
             .onTapGesture { selectedHashtagForAnalytics = hashtag }
         }
    }

    private var trendingHashtagsSection: some View {
        Section(header: Text("Trending Today").font(.headline)) {
            ForEach(trendingHashtags) { hashtag in
                 HStack {
                     Text("#\(hashtag.name)").foregroundColor(.blue)
                     Spacer()
                     if hashtag.history?.isEmpty == false {
                          Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.gray)
                     }
                 }
                 .contentShape(Rectangle())
                 .onTapGesture {
                     selectedHashtagForAnalytics = hashtag
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
        NavigationView {
            SearchFiltersView(filters: $searchFilters) {
                 Task { await search(query: searchText) }
                 showSearchFilters = false
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showSearchFilters = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                         Task { await search(query: searchText) }
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
             selectedTimeRange: .constant(.day),
             showHashtagAnalytics: Binding(
                 get: { selectedHashtagForAnalytics != nil },
                 set: { if !$0 { selectedHashtagForAnalytics = nil } }
             )
         )
         .environmentObject(timelineViewModel)
    }

     private func detailSheet(post: Post) -> some View {
         PostDetailView(
             post: post,
             showDetail: Binding(
                 get: { selectedPostForDetail != nil },
                 set: { if !$0 { selectedPostForDetail = nil } }
             )
         )
     }

    private func triggerGlow() {
        withAnimation {
            showGlow = true
        }
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 1.0)) {
                showGlow = false
            }
        }
    }

    // MARK: - Data Logic
    private func search(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            self.searchResults = SearchResults()
            return
        }

        isLoading = true
        error = nil

        do {
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
            self.searchResults = results
        } catch is CancellationError {
            // Task was cancelled, so we can ignore it.
        } catch let fetchError {
            self.error = IdentifiableError(message: "Search failed: \(fetchError.localizedDescription)")
            self.searchResults = SearchResults()
        }

        isLoading = false
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

    private func loadTrendingHashtags() async {
        isLoading = true
        error = nil
        do {
            trendingHashtags = try await searchService.fetchTrendingHashtags()
        } catch let fetchError {
            self.error = IdentifiableError(message: "Could not load trending tags: \(fetchError.localizedDescription)")
            self.trendingHashtags = []
        }
        isLoading = false
    }

    private func clearSearch() {
        searchResults = SearchResults()
    }
}


// MARK: - Placeholder Views (Ensure these exist)
struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    var onApply: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
             Section("General") {
                 Toggle("Include Full Profile Data (Resolve)", isOn: Binding(
                     get: { filters.resolve ?? true },
                     set: { filters.resolve = $0 }
                 ))
                 Toggle("Exclude Unreviewed Content", isOn: Binding(
                      get: { filters.excludeUnreviewed ?? false },
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
                 ), in: 5...40, step: 5)
             }
         }
    }
}
