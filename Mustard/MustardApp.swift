//
//  MustardApp.swift
//  Mustard
//
//  Created by Vaibhav Srivastava on 14/09/24.
//  Copyright © 2024 Mustard. All rights reserved.
//

#if os(iOS)

import SwiftUI
import SwiftData
import OSLog
import UIKit

@main
struct MustardApp: App {
    
    // MARK: - Shared Network & Environment
    static let mastodonAPIServiceInstance = MastodonAPIService()
    
    @State private var appEnvironment = AppEnvironment()
    @State private var cacheService = CacheService(mastodonAPIService: MustardApp.mastodonAPIServiceInstance)
    @State private var locationManager = LocationManager()
    @State private var appServices: AppServices
    
    // MARK: - SwiftData Container
    static var sharedModelContainer: ModelContainer!
    private let container: ModelContainer

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

        // 2. Initialize AppServices
        let services = AppServices(
            mastodonAPIService: MustardApp.mastodonAPIServiceInstance,
            recommendationService: RecommendationService.shared
        )
        _appServices = State(wrappedValue: services)

        print("[MustardApp] init() completed. AppServices ready.")
    }

    // Extract view builder into a computed property
    @ViewBuilder
    private var contentView: some View {
        switch appEnvironment.authState {
        case .checking:
            ProgressView("Loading...")
        case .unauthenticated, .authenticating:
            LoginView()
        case .authenticated:
            MainAppView()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                contentView
            }
            .modelContainer(container)
            .environment(appEnvironment)
            .environment(locationManager)
            .environment(cacheService)
            .environment(appServices.timelineService)
            .environment(appServices.trendingService)
            .environment(appServices.postActionService)
            .environment(appServices.profileService)
            .environment(appServices.searchService)
            .environment(appServices.recommendationService)
        }
    }
}

#endif
