//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import OSLog
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabView {
                    // Home Tab
                    NavigationStack {
                        HomeView()
                            .environmentObject(timelineViewModel)
                            .environmentObject(locationManager)
                    }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                    // Settings Tab
                    NavigationStack {
                        SettingsView()
                            .environmentObject(authViewModel)
                            .environmentObject(timelineViewModel)
                            .environmentObject(locationManager)
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .didReceiveOAuthCallback,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                .alert(item: $timelineViewModel.alertError) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else {
                NavigationStack {
                    AuthenticationView()
                        .environmentObject(authViewModel)
                        .navigationTitle("Sign In")
                }
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .didReceiveOAuthCallback,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                .alert(item: $authViewModel.alertError) { error in
                    Alert(
                        title: Text("Authentication Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .onAppear {
            Task {
                await authViewModel.validateAuthentication()
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize Mock Service for Preview
        let mockService = MockService(shouldSucceed: true)

        // Initialize Model Container with Required Models
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Initialize ViewModels with Mock Service and Context
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService, authViewModel: authViewModel)
        let locationManager = LocationManager()

        // Populate ViewModels with Mock Data
        timelineViewModel.posts = mockService.mockPosts
        timelineViewModel.topPosts = mockService.mockTrendingPosts

        return ContentView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(locationManager)
            .modelContainer(container)
    }
}
