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

    // Inject the required services for TimelineViewModel and ProfileViewModel
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let cacheService: CacheService
    let networkService: NetworkService

    var body: some View {
        TabView {
            // Home Tab
            NavigationStack {
                HomeView(
                    authViewModel: authViewModel,
                    locationManager: locationManager,
                    timelineViewModel: TimelineViewModel(
                        timelineService: timelineService,
                        cacheService: cacheService, // Pass the correct CacheService
                        networkService: networkService, // Pass the correct NetworkService
                        trendingService: trendingService, // Pass the correct TrendingService
                        postActionService: postActionService, // Pass the correct PostActionService
                        locationManager: locationManager // Pass the correct LocationManager
                    ),
                    profileViewModel: ProfileViewModel(
                        profileService: profileService,
                        authenticationService: authViewModel.authenticationService // Pass the service directly
                    )
                )
                .environmentObject(authViewModel) // Injecting authViewModel
                .environmentObject(locationManager) // Injecting locationManager
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // Profile Tab
            NavigationStack {
                if let currentUser = authViewModel.currentUser {
                    ProfileView(user: currentUser)
                        .environmentObject(ProfileViewModel(
                            profileService: profileService,
                            authenticationService: authViewModel.authenticationService // Pass the service directly
                        ))
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

            // Settings Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(authViewModel)
                    .environmentObject(locationManager)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
