//
//  MustardApp.swift
//  Mustard
//
//  Created by Vaibhav Srivastava on 14/09/24.
//  Copyright © 2024 Mustard. All rights reserved.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct MustardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Services
    static private let networkService = NetworkService.shared
    private let cacheService = CacheService()

    // MARK: - ViewModels
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var weatherService: WeatherService! // Add WeatherService

    // MARK: - SwiftData container
    let container: ModelContainer

    // MARK: - Services
    @State private var timelineService: TimelineService!
    @State private var trendingService: TrendingService!
    @State private var postActionService: PostActionService!
    @State private var profileService: ProfileService!

    // MARK: - Initialization
    init() {
        // Initialize ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self, ServerModel.self)
            print("[MustardApp] ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Initialize weatherService before using it in any other services
        let weatherService = WeatherService()

        // Initialize services with proper dependencies
        let postActionService = PostActionService(networkService: MustardApp.networkService)
        let trendingService = TrendingService(networkService: MustardApp.networkService, cacheService: cacheService)
        let timelineService = TimelineService(
            networkService: MustardApp.networkService,
            cacheService: cacheService,
            postActionService: postActionService,
            locationManager: LocationManager(),
            trendingService: trendingService
        )

        // Initialize all other services
        _timelineService = State(initialValue: timelineService)
        _trendingService = State(initialValue: trendingService)
        _postActionService = State(initialValue: postActionService)
        _profileService = State(initialValue: ProfileService(networkService: MustardApp.networkService))
        _weatherService = State(initialValue: weatherService) // Initialize WeatherService state
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authViewModel.authState {
                case .unauthenticated, .authenticating:
                    LoginView()
                case .authenticated:
                    MainAppView(
                        timelineService: timelineService,
                        trendingService: trendingService,
                        postActionService: postActionService,
                        profileService: profileService,
                        cacheService: cacheService,
                        networkService: MustardApp.networkService,
                        weatherService: weatherService // Pass WeatherService instance
                    )
                }
            }
            .environmentObject(authViewModel)
            .environmentObject(locationManager)
            .modelContainer(container)
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AppDelegate")

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        logger.info("Received OAuth callback URL: \(url.absoluteString, privacy: .public)")
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}

