//
//  MustardApp.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import OSLog
import SwiftData

@main
struct MustardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - ViewModels
    @StateObject private var authViewModel: AuthenticationViewModel = {
        // Initialize your MastodonService (or MockMastodonService for testing)
        let mastodonService = MastodonService.shared // Or MockMastodonService(shouldSucceed: true)
        return AuthenticationViewModel(mastodonService: mastodonService)
    }()
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
            // Authentication Flow: Authentication View is now the root view
            NavigationStack {
                AuthenticationView()
                    .environmentObject(authViewModel)
                    .environmentObject(locationManager)
                    .modelContainer(container)
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
