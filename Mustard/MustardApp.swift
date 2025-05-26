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

    // MARK: - Shared Instances & Managers
    static private let mastodonAPIServiceInstance = MastodonAPIService() // single instance
    
    @StateObject private var cacheService: CacheService   // will be initialized in init()
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var locationManager = LocationManager()
    
    // MARK: - SwiftData Container
    let container: ModelContainer
    
    // MARK: - Service Environment
    @StateObject private var appServices: AppServices

    // MARK: - Initialization
    init() {
        // 1. SwiftData ModelContainer
        do {
            let schema = Schema([
                Account.self, MediaAttachment.self, Post.self, ServerModel.self,
                Tag.self, Item.self, InstanceModel.self, InstanceInformationModel.self
            ])
            let modelConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfig])
            print("[MustardApp] ModelContainer initialized.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 2. Initialize CacheService with MastodonAPIService instance
        let initialCache = CacheService(mastodonAPIService: MustardApp.mastodonAPIServiceInstance)
        _cacheService = StateObject(wrappedValue: initialCache)

        // 3. Initialize AppServices using the shared instances
        let services = AppServices(
            mastodonAPIService: MustardApp.mastodonAPIServiceInstance,
            cacheService: initialCache,
            locationManager: self.locationManager
        )
        _appServices = StateObject(wrappedValue: services)

        print("[MustardApp] init() completed. AppServices & CacheService ready.")
        Logger(subsystem: "titan.mustard.app", category: "App").info("AppServices initialized.")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authViewModel.authState {
                case .checking:
                    ProgressView("Loading...")
                case .unauthenticated, .authenticating:
                    LoginView()
                        .environmentObject(authViewModel)
                        .environmentObject(locationManager)
                case .authenticated:
                    MainAppView(
                        timelineService: appServices.timelineService,
                        trendingService: appServices.trendingService,
                        postActionService: appServices.postActionService,
                        profileService: appServices.profileService,
                        searchService: appServices.searchService,
                        cacheService: cacheService,
                        locationManager: locationManager
                        // Removed: direct mastodonAPIService injection
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(locationManager)
                    .environmentObject(cacheService)
                }
            }
            .modelContainer(container)
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AppDelegate")
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        logger.info("Received OAuth callback URL: \(url.absoluteString, privacy: .public)")
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
