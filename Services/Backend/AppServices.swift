//
//  AppServices.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 04/04/25.
//  (REVISED: Modernized to @Observable and clean dependencies)

import Foundation
import OSLog
import Observation

@MainActor
@Observable
class AppServices {
    // MARK: - Services
    let mastodonAPIService: MastodonAPIService
    let timelineService: TimelineService
    let trendingService: TrendingService
    let postActionService: PostActionService
    let profileService: ProfileService
    let searchService: SearchService
    let recommendationService: RecommendationService

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AppServices")

    // MARK: - Initialization
    init(
        mastodonAPIService: MastodonAPIService,
        recommendationService: RecommendationService
    ) {
        self.logger.info("Initializing AppServices...")
        self.mastodonAPIService = mastodonAPIService
        self.recommendationService = recommendationService

        let postActionService = PostActionService(mastodonAPIService: mastodonAPIService)
        let profileService = ProfileService(mastodonAPIService: mastodonAPIService)
        let searchService = SearchService(mastodonAPIService: mastodonAPIService)
        let trendingService = TrendingService(mastodonAPIService: mastodonAPIService)

        let timelineService = TimelineService(
            mastodonAPIService: mastodonAPIService,
            postActionService: postActionService,
            trendingService: trendingService,
            recommendationService: recommendationService
        )

        self.postActionService = postActionService
        self.profileService = profileService
        self.searchService = searchService
        self.trendingService = trendingService
        self.timelineService = timelineService

        self.logger.info("AppServices initialized successfully.")
    }
}
