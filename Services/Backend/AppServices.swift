//
//  AppServices.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 04/04/25.
// (REVISED: Updated to use MastodonAPIService and ensure correct dependency injection)

import Foundation
import OSLog

@MainActor
class AppServices: ObservableObject {
    // MARK: - Services
    let mastodonAPIService: MastodonAPIService // Core Mastodon API interactions
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let searchService: SearchService
    // InstanceService is independent and can be instantiated where needed or here if used globally
    // let instanceService: InstanceService
    // AuthenticationService is a shared instance, typically not directly managed by AppServices container
    // CacheService and LocationManager are often managed at a higher level (e.g., MustardApp) and passed around or as EnvironmentObjects

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AppServices")

    // MARK: - Initialization
    init(
        mastodonAPIService: MastodonAPIService, // Core networking dependency for Mastodon
        cacheService: CacheService,
        locationManager: LocationManager
        // keychainHelper: KeychainHelper // If needed directly by AppServices, though usually a dependency of MastodonAPIService or AuthService
    ) {
        self.logger.info("Initializing AppServices with MastodonAPIService...")
        self.mastodonAPIService = mastodonAPIService

        // 1. Initialize services that depend directly on MastodonAPIService
        //    (Ensure these service's initializers are updated to accept MastodonAPIService)
        let postActionService = PostActionService(mastodonAPIService: mastodonAPIService)
        let profileService = ProfileService(mastodonAPIService: mastodonAPIService)
        let searchService = SearchService(mastodonAPIService: mastodonAPIService) //

        // 2. Initialize services that might depend on other services or cache/location
        let trendingService = TrendingService(mastodonAPIService: mastodonAPIService, cacheService: cacheService) //

        // 3. TimelineService often depends on several other services
        let timelineService = TimelineService(
            mastodonAPIService: mastodonAPIService, // Pass the main API service
            cacheService: cacheService,
            postActionService: postActionService,
            locationManager: locationManager,
            trendingService: trendingService // Pass the already initialized trending service
        )

        // Assign services to properties
        self.postActionService = postActionService
        self.profileService = profileService
        self.searchService = searchService
        self.trendingService = trendingService
        self.timelineService = timelineService
        // self.instanceService = InstanceService() // If managing it here

        self.logger.info("AppServices initialized successfully.")
    }
}
