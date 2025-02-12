//
//  MainAppView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import OSLog
import SwiftData

struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager

    // Services
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let cacheService: CacheService
    let networkService: NetworkService
    let weatherService: WeatherService

    /// Hold a single source of truth for your TimelineViewModel so it’s reused
    @StateObject private var timelineViewModel: TimelineViewModel

    /// Custom initializer to inject everything we need:
    init(
        timelineService: TimelineService,
        trendingService: TrendingService,
        postActionService: PostActionService,
        profileService: ProfileService,
        cacheService: CacheService,
        networkService: NetworkService,
        weatherService: WeatherService
    ) {
        self.timelineService = timelineService
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.profileService = profileService
        self.cacheService = cacheService
        self.networkService = networkService
        self.weatherService = weatherService

        // Initialize the ViewModel
        _timelineViewModel = StateObject(
            wrappedValue: TimelineViewModel(
                timelineService: timelineService,
                weatherService: weatherService,
                locationManager: LocationManager() // or pass a placeholder; can be replaced later
            )
        )
    }

    var body: some View {
        TabView {

            // MARK: - Home Tab
            NavigationStack {
                /// Use a custom “TimelineScreen” (or any custom name) instead of SwiftUI's TimelineView.
                TimelineScreen(viewModel: timelineViewModel)
                    .navigationTitle("Timeline")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // MARK: - Profile Tab
            NavigationStack {
                if let currentUser = authViewModel.currentUser {
                    // Only pass 'currentUser' if ProfileView expects it and does not need 'viewModel'
                    ProfileView(user: currentUser)
                        .environmentObject(authViewModel)
                } else {
                    Text("Please log in to view your profile.")
                        .foregroundColor(.gray)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }

            // MARK: - Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        // Make sure environment objects are available throughout:
        .environmentObject(authViewModel)
        .environmentObject(locationManager)
    }
}
