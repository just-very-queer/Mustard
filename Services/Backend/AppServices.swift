//
//  AppServices.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 04/04/25.
//  (REVISED: Updated to use MastodonAPIService and ensure correct dependency injection)

import Foundation
import OSLog

@MainActor
class AppServices: ObservableObject {
    // MARK: - Services
    let mastodonAPIService: MastodonAPIService
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let searchService: SearchService
    let recommendationService: RecommendationService // Added service

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AppServices")

    // MARK: - Initialization
    init(
        mastodonAPIService: MastodonAPIService,
        cacheService: CacheService,
        locationManager: LocationManager,
        recommendationService: RecommendationService // Added to initializer
    ) {
        self.logger.info("Initializing AppServices...")
        self.mastodonAPIService = mastodonAPIService
        self.recommendationService = recommendationService // Store the service

        // Initialize other services that depend on mastodonAPIService, cache, location, etc.
        let postActionService = PostActionService(mastodonAPIService: mastodonAPIService)
        let profileService = ProfileService(mastodonAPIService: mastodonAPIService)
        let searchService = SearchService(mastodonAPIService: mastodonAPIService)
        let trendingService = TrendingService(mastodonAPIService: mastodonAPIService, cacheService: cacheService)

        // TimelineService depends on other services but NOT directly on recommendationService
        let timelineService = TimelineService(
            mastodonAPIService: mastodonAPIService,
            cacheService: cacheService,
            postActionService: postActionService,
            locationManager: locationManager,
            trendingService: trendingService
        )

        // Assign to properties
        self.postActionService = postActionService
        self.profileService = profileService
        self.searchService = searchService
        self.trendingService = trendingService
        self.timelineService = timelineService

        self.logger.info("AppServices initialized successfully.")
    }
}
