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
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(LocationManager.self) private var locationManager
    @Environment(CacheService.self) private var cacheService
    @Environment(TimelineService.self) private var timelineService
    @Environment(TrendingService.self) private var trendingService
    @Environment(PostActionService.self) private var postActionService
    @Environment(ProfileService.self) private var profileService
    @Environment(RecommendationService.self) private var recommendationService

    var body: some View {
        TabView {
            // MARK: - Home Tab
            TimelineScreen()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            // MARK: - Profile Tab
            NavigationStack {
                if let currentUser = appEnvironment.currentUser {
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
    }
}
