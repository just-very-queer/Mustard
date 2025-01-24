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

    var body: some View {
        TabView {
            // Home Tab
            NavigationStack {
                HomeView(
                    authViewModel: authViewModel,
                    locationManager: locationManager,
                    timelineViewModel: TimelineViewModel(
                        timelineService: timelineService,
                        trendingService: trendingService,
                        postActionService: postActionService,
                        locationManager: locationManager
                    ),
                    profileViewModel: ProfileViewModel(
                        profileService: profileService,
                        authenticationService: authViewModel.authenticationService // Removed the `$`
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
                            authenticationService: authViewModel.authenticationService // Removed the `$`
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
