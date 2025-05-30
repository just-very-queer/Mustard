import SwiftUI
import SwiftData

@main
struct MustardWatchApp: App {
    
    let modelContainer: ModelContainer

    init() {
        // Define the schema including all models that need to be accessed on the watch
        let schema = Schema([
            Post.self, Account.self, MediaAttachment.self, Interaction.self, 
            UserAffinity.self, HashtagAffinity.self, Card.self, Tag.self // Ensure Tag.self is included
            // Add other models like User.self, Mention.self if they are separate @Model classes
        ])
        
        // IMPORTANT: Replace this with your actual App Group ID
        let appGroupIdentifier = "group.com.example.Mustard" 
                                 // ^^^^^ USER ACTION: REPLACE THIS ^^^^^

        let modelConfiguration: ModelConfiguration
        
        // Attempt to get the App Group container URL
        if let groupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = groupContainerURL.appendingPathComponent("Mustard.sqlite")
            modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL, // Use the path in the App Group
                groupContainer: .identifier(appGroupIdentifier) // Specify the group container
            )
            print("WatchApp: Using App Group shared data store at: \(storeURL.path)")
        } else {
            // Fallback for local testing if App Group isn't set up in the build environment
            // or if running in a simulator without App Group entitlements fully synced.
            print("WatchApp: App Group not configured or accessible. Using non-shared, in-memory container for watchOS.")
            // Using an in-memory store as a fallback for the watch is often not useful
            // unless you have specific WatchConnectivity logic to sync data.
            // For a glance view relying on shared data, this fallback means it won't see iOS data.
            // Consider a non-shared, persistent store for watch-only data if App Group fails.
            // For this example, we'll stick to a persistent, non-shared store if App Group fails.
            let localStoreURL = URL.applicationSupportDirectory.appendingPathComponent("MustardWatchLocal.sqlite")
            modelConfiguration = ModelConfiguration(schema: schema, url: localStoreURL)
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
                // The RecommendationService is configured in init(), so it's ready.
                // If ContentView needs direct access to the ModelContext:
                // .modelContext(modelContainer.mainContext) 
                // However, it's better if views primarily interact with services or ViewModels.
        }
    }
}
