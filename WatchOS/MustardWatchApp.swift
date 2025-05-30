//
//  MustardWatchApp.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
// (REVISED & FIXED)

import SwiftUI
import SwiftData

struct MustardWatchApp: App {
    
    let modelContainer: ModelContainer

    init() {
        // Define the schema including all models that need to be accessed on the watch
        let schema = Schema([
            Post.self, Account.self, MediaAttachment.self, Interaction.self,
            UserAffinity.self, HashtagAffinity.self, Tag.self // Ensure Tag.self is included
        ])
        
        // IMPORTANT: Replace this with your actual App Group ID
        let appGroupIdentifier = "titan.mustard.app.ao"
        let modelConfiguration: ModelConfiguration
        
        // Attempt to get the App Group container URL
        if let groupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = groupContainerURL.appendingPathComponent("Mustard.sqlite")
            
            // FIX: Removed the 'url' parameter. It is an extra argument when 'groupContainer' is also specified.
            // SwiftData will automatically manage the database URL within the app group container.
            modelConfiguration = ModelConfiguration(
                "SharedStore", // Configuration name
                schema: schema,
                groupContainer: .identifier(appGroupIdentifier) // Specify the group container
            )
            print("WatchApp: Using App Group shared data store at: \(storeURL.path)")
        } else {
            // Fallback for local testing if App Group isn't set up in the build environment
            print("WatchApp: App Group not configured or accessible. Using non-shared, local container for watchOS.")
            let localStoreURL = URL.applicationSupportDirectory.appendingPathComponent("MustardWatchLocal.sqlite")
            
            // This initializer is correct because it provides a specific URL for a non-shared container.
            modelConfiguration = ModelConfiguration("LocalStore", schema: schema, url: localStoreURL)
             print("WatchApp: Using local data store at: \(localStoreURL.path)")
        }

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Configure the shared RecommendationService instance with the watch app's model context
            RecommendationService.shared.configure(modelContext: ModelContext(modelContainer))
            
        } catch {
            // If the container fails to load, it's a critical error.
            fatalError("Could not create ModelContainer for watchOS: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
