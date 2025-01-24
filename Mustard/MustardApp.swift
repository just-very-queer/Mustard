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

    // MARK: - Services
    static private let networkService = NetworkService.shared // Now static
    private let cacheService = CacheService()
    private let authenticationService = AuthenticationService()
    private let timelineService: TimelineService
    private let trendingService: TrendingService
    private let postActionService: PostActionService
    private let profileService: ProfileService

    // MARK: - ViewModels
    @StateObject private var authViewModel: AuthenticationViewModel
    @StateObject private var locationManager = LocationManager()

    // MARK: - SwiftData container
    let container: ModelContainer

    // MARK: - Initialization
    init() {
        // Initialize the ModelContainer with your @Model types
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self, Server.self)
            print("[MustardApp] ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Initialize the AuthenticationService
        let authViewModelInstance = AuthenticationViewModel(authenticationService: authenticationService)
        _authViewModel = StateObject(wrappedValue: authViewModelInstance)

        // Initialize other services using the static networkService
        timelineService = TimelineService(networkService: Self.networkService, cacheService: cacheService)
        trendingService = TrendingService(networkService: Self.networkService, cacheService: cacheService)
        postActionService = PostActionService(networkService: Self.networkService)
        profileService = ProfileService(networkService: Self.networkService)
    }

    var body: some Scene {
            WindowGroup {
                // Inject dependencies into MainAppView
                if authViewModel.isAuthenticated {
                    MainAppView(
                        timelineService: timelineService,
                        trendingService: trendingService,
                        postActionService: postActionService,
                        profileService: profileService,
                        cacheService: cacheService,
                        networkService: MustardApp.networkService // Pass the networkService directly
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(locationManager)
                    .modelContainer(container)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                        .environmentObject(locationManager)
                        .modelContainer(container)
                }
            }
    }

    // MARK: - Helper to Create ModelContainer
    private static func createModelContainer() -> ModelContainer {
        do {
            let container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self, Server.self)
            print("[MustardApp] ModelContainer initialized successfully.")
            return container
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
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

        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
