//
//  MustardApp.swift
//  Mustard
//
//  Created by Vaibhav Srivastava on 14/09/24.
//  Copyright © 2024 Mustard. All rights reserved.
//

// Change the conditional compilation from canImport(UIKit) to os(iOS)
// to be more specific about the platform for this app entry point.
#if os(iOS) // Changed from canImport(UIKit)

import SwiftUI
import SwiftData
import OSLog
import UIKit

@main
struct MustardApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Shared Instances & Managers
    static let mastodonAPIServiceInstance = MastodonAPIService() // single instance
    
    @StateObject private var cacheService: CacheService
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var locationManager: LocationManager
    
    // MARK: - SwiftData Container
    static var sharedModelContainer: ModelContainer!
    private let container: ModelContainer
    
    // MARK: - Service Environment
    @StateObject private var appServices: AppServices

    // MARK: - Initialization
    init() {
        // 1. SwiftData ModelContainer
        do {
            let schema = Schema([
                Account.self, MediaAttachment.self, Post.self, ServerModel.self,
                Tag.self, InstanceModel.self, InstanceInformationModel.self,
                Interaction.self, UserAffinity.self, HashtagAffinity.self
            ])
            let modelConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let newContainer = try ModelContainer(for: schema, configurations: [modelConfig])
            self.container = newContainer
            MustardApp.sharedModelContainer = newContainer
            
            RecommendationService.shared.configure(modelContext: ModelContext(newContainer))
            
            print("[MustardApp] ModelContainer and RecommendationService configured.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 2. Create LocationManager instance locally
        let locManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locManager)
        
        // 3. Initialize CacheService
        let initialCache = CacheService(mastodonAPIService: MustardApp.mastodonAPIServiceInstance)
        _cacheService = StateObject(wrappedValue: initialCache)

        // 4. Initialize AppServices
        let services = AppServices(
            mastodonAPIService: MustardApp.mastodonAPIServiceInstance,
            cacheService: initialCache,
            locationManager: locManager,
            recommendationService: RecommendationService.shared
        )
        _appServices = StateObject(wrappedValue: services)

        print("[MustardApp] init() completed. AppServices & CacheService ready.")
        Logger(subsystem: "titan.mustard.app", category: "App").info("AppServices initialized.")
    }

    // Extract view builder into a computed property
    @ViewBuilder
    private var contentView: some View {
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
                locationManager: locationManager,
                recommendationService: RecommendationService.shared
            )
            .environmentObject(authViewModel)
            .environmentObject(locationManager)
            .environmentObject(cacheService)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                contentView
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
#endif // os(iOS)
