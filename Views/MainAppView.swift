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
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let searchService: SearchService
    let recommendationService: RecommendationService // Added to store the passed instance

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
        searchService: SearchService,
        cacheService: CacheService,
        locationManager: LocationManager,
        recommendationService: RecommendationService // Added parameter
    ) {
        self.timelineService = timelineService
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.profileService = profileService
        self.searchService = searchService
        self.recommendationService = recommendationService // Store the instance

        // Initialize the ViewModels, passing all required dependencies
        _timelineViewModel = StateObject(
            wrappedValue: TimelineViewModel(
                timelineService: timelineService,
                locationManager: locationManager,
                trendingService: trendingService,
                postActionService: postActionService,
                cacheService: cacheService,
                recommendationService: recommendationService // FIX: Pass the instance
            )
        )

        _profileViewModel = StateObject(
            wrappedValue: ProfileViewModel(profileService: profileService)
        )

        _searchViewModel = StateObject(
            wrappedValue: SearchViewModel(searchService: searchService)
        )
    }

    var body: some View {
        TabView {
            // MARK: - Home Tab
            NavigationStack(path: $timelineViewModel.navigationPath) {
                TimelineScreen(viewModel: timelineViewModel)
                    .navigationTitle("Timeline")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // MARK: - Profile Tab
            NavigationStack {
                if let currentUser = authViewModel.currentUser {
                    ProfileView(user: currentUser)
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
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            // MARK: - Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        // Inject ViewModels and other objects into the environment for descendant views
        .environmentObject(authViewModel)
        .environmentObject(locationManager)
        .environmentObject(timelineViewModel)
        .environmentObject(profileViewModel)
        .environmentObject(searchViewModel)
        .environmentObject(cacheService)
        // Note: recommendationService is not typically added to the environment unless multiple disconnected views need it.
        // It's passed directly to ViewModels that require it during their initialization.
    }
}
