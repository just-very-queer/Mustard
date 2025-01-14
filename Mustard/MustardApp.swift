//
//  MustardApp.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct MustardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - ViewModels
    @StateObject private var authViewModel: AuthenticationViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
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

        // Initialize authViewModel first
        let mockService = MockMastodonService(shouldSucceed: true) // Use MockService for previews/testing
        let authVM = AuthenticationViewModel(mastodonService: mockService)
        _authViewModel = StateObject(wrappedValue: authVM)

        // Initialize timelineViewModel with authViewModel
        let timelineVM = TimelineViewModel(
            mastodonService: mockService,
            authViewModel: authVM
        )
        _timelineViewModel = StateObject(wrappedValue: timelineVM)
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
                                .environmentObject(locationManager)
                                .modelContainer(container)
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
                                .modelContainer(container)
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
                        print("[MustardApp] Received URL via onOpenURL: \(url.absoluteString)")
                    }
                    .alert(item: $timelineViewModel.alertError) { (error: AppError) in
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
                        .environmentObject(locationManager)
                        .modelContainer(container)
                        .alert(item: $authViewModel.alertError) { (error: AppError) in
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
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AppDelegate")
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Log the received OAuth callback URL for debugging
        logger.info("Received OAuth callback URL: \(url.absoluteString, privacy: .public)")
        
        // Notify about the received URL for OAuth callback
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
