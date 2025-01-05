//
//  MustardApp.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import SwiftData

@main
struct MustardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - ViewModels
    @StateObject private var authViewModel = AuthenticationViewModel(mastodonService: MastodonService.shared)
    @StateObject private var timelineViewModel = TimelineViewModel(mastodonService: MastodonService.shared)
    @StateObject private var topPostsViewModel = TopPostsViewModel(service: MastodonService.shared)
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var locationManager = LocationManager()

    // MARK: - SwiftData container
    let container: ModelContainer

    // MARK: - Initialization
    init() {
        // Initialize the ModelContainer with your @Model types
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
            print("[MustardApp] ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    // Main App with Tabs
                    TabView {
                        // Home Tab
                        NavigationStack {
                            HomeView()
                                .environmentObject(authViewModel)
                                .environmentObject(timelineViewModel)
                                .environmentObject(topPostsViewModel)
                                .environmentObject(weatherViewModel)
                                .environmentObject(locationManager)
                                .modelContainer(container)
                        }
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }

                        // Additional Tabs (if any) can be added here
                    }
                    .onOpenURL { url in
                        NotificationCenter.default.post(
                            name: .didReceiveOAuthCallback,
                            object: nil,
                            userInfo: ["url": url]
                        )
                        print("[MustardApp] Received URL via onOpenURL: \(url.absoluteString)")
                    }
                    .alert(item: $timelineViewModel.alertError) { error in
                        Alert(
                            title: Text("Error"),
                            message: Text(error.message),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                } else {
                    // Authentication Flow: Authentication View
                    AuthenticationView()
                        .environmentObject(authViewModel)
                        .environmentObject(timelineViewModel)
                        .environmentObject(topPostsViewModel)
                        .environmentObject(weatherViewModel)
                        .environmentObject(locationManager)
                        .modelContainer(container)
                        .navigationTitle("Authentication")
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
                print("[MustardApp] App appeared. Validating authentication.")
            }
        }
    }
}

/// AppDelegate class to handle application-level events, such as OAuth callbacks.
class AppDelegate: NSObject, UIApplicationDelegate {
    /// Handles incoming URLs (e.g., OAuth callback URLs).
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("Received OAuth callback URL: \(url.absoluteString)")
        // Notify about received URL for OAuth callback
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
