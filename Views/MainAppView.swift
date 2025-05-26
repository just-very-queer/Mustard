//
//  MainAppView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
// (REVISED: Removed NetworkService dependency, aligned with MastodonAPIService)

import SwiftUI
import OSLog
import SwiftData

struct MainAppView: View {
    // Environment Objects (Passed from MustardApp)
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var cacheService: CacheService // Receives from environment

    // Services (Passed from MustardApp - stored for ViewModel initialization)
    // These are the services created by AppServices, which should now be using MastodonAPIService
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let searchService: SearchService // Assuming SearchService is also passed via AppServices

    // State Objects (Initialized here, single source of truth for these ViewModels within MainAppView scope)
    @StateObject private var timelineViewModel: TimelineViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var searchViewModel: SearchViewModel // For the Search tab

    // Initializer to receive services and create ViewModels
    init(
        timelineService: TimelineService,
        trendingService: TrendingService,
        postActionService: PostActionService,
        profileService: ProfileService,
        searchService: SearchService, // Added SearchService
        cacheService: CacheService,
        locationManager: LocationManager,
    ) {
        self.timelineService = timelineService
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.profileService = profileService
        self.searchService = searchService

        // Initialize the ViewModels, passing all required dependencies
        _timelineViewModel = StateObject(
            wrappedValue: TimelineViewModel(
                timelineService: timelineService,
                locationManager: locationManager,
                trendingService: trendingService,
                postActionService: postActionService,
                cacheService: cacheService
            )
        )

        _profileViewModel = StateObject(
            wrappedValue: ProfileViewModel(profileService: profileService)
        )

        // Initialize SearchViewModel, ensuring SearchService is correctly configured
        // SearchService itself should have been initialized with MastodonAPIService by AppServices
        _searchViewModel = StateObject(
            wrappedValue: SearchViewModel(searchService: searchService)
        )
    }

    var body: some View {
        TabView {
            // MARK: - Home Tab
            NavigationStack(path: $timelineViewModel.navigationPath) { // Use ViewModel's path
                TimelineScreen(viewModel: timelineViewModel)
                    .navigationTitle("Timeline")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // MARK: - Profile Tab
            NavigationStack {
                if let currentUser = authViewModel.currentUser { //
                    ProfileView(user: currentUser) //
                    // EnvironmentObjects for ProfileView and its children are provided globally below
                } else {
                    Text("Please log in to view your profile.")
                        .foregroundColor(.gray)
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }

            // MARK: - Search Tab
            NavigationStack {
                SearchView() //
                // EnvironmentObjects for SearchView are provided globally below
                // It uses its own @StateObject for SearchViewModel
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            // MARK: - Settings Tab
            NavigationStack {
                SettingsView() //
                // EnvironmentObjects for SettingsView are provided globally below
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        // Inject ViewModels and other objects into the environment for descendant views
        .environmentObject(authViewModel) //
        .environmentObject(locationManager) //
        .environmentObject(timelineViewModel) // Make timelineViewModel available globally
        .environmentObject(profileViewModel)  // Make profileViewModel available globally
        .environmentObject(searchViewModel) // Make searchViewModel available globally for search tab
        .environmentObject(cacheService)     // Make cacheService available globally
    }
}
