import SwiftUI
import SwiftData

struct ContentView: View {
    // RecommendationService is configured in MustardWatchApp's init.
    // We can access it as a shared instance.
    private let recommendationService = RecommendationService.shared
    
    @State private var topPosts: [Post] = []
    @State private var isLoading: Bool = true

    // Query to fetch Post objects by ID.
    // This approach fetches all posts into memory on the watch, then filters.
    // This is highly inefficient for a large number of posts.
    // A better long-term solution would be for RecommendationService to have a method
    // that directly fetches and returns fully populated Post objects or DTOs using their IDs,
    // or for the watch to construct more targeted FetchDescriptors.
    // For this exercise, we proceed with the simpler (but less performant) filtering approach.
    @Query(sort: [SortDescriptor(\Post.createdAt, order: .reverse)]) var allPostsInDatabase: [Post]

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                } else if topPosts.isEmpty {
                    Text("No recommendations available at the moment.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(topPosts.prefix(3)) { post in // Show top 3
                            VStack(alignment: .leading, spacing: 4) {
                                if let account = post.account {
                                    Text(account.displayName ?? account.username ?? "Unknown Author")
                                        .font(.headline)
                                        .lineLimit(1)
                                } else {
                                    Text("Unknown Author")
                                        .font(.headline)
                                }
                                
                                Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                                    .font(.footnote)
                                    .lineLimit(2) // Show a snippet of the content
                                
                                Text(post.createdAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("For You")
            .task {
                await loadTopPosts()
            }
        }
    }

    @MainActor
    func loadTopPosts() async {
        // Ensure RecommendationService's context is configured. This should happen in App init.
        // If modelContext is nil in RecommendationService, it will log critical errors and return empty.
        
        isLoading = true
        let recommendedIDs = await recommendationService.topRecommendations(limit: 5) // Fetch 5 IDs
        
        if recommendedIDs.isEmpty && !allPostsInDatabase.isEmpty {
            // If no specific recommendations, but there are posts, show the latest as a fallback.
            // This is a simple fallback; more sophisticated logic could be applied.
            // self.topPosts = Array(allPostsInDatabase.prefix(3))
            // For now, stick to only showing "For You" or "No recommendations".
            // If topRecommendations returns empty, it implies no strong signals.
            self.topPosts = []
             print("WatchApp: No specific recommendations found. TopPosts will be empty.")
        } else if recommendedIDs.isEmpty && allPostsInDatabase.isEmpty {
            self.topPosts = []
            print("WatchApp: No recommendations and no posts in local database.")
        }
        else {
            // Filter allPostsInDatabase to get the recommended ones
            // This is inefficient for large datasets on the watch.
            var foundPosts: [Post] = []
            for idToFind in recommendedIDs {
                if let post = allPostsInDatabase.first(where: { $0.id == idToFind }) {
                    foundPosts.append(post)
                }
                if foundPosts.count >= 3 { // Stop once we have enough for the glance
                    break
                }
            }
            self.topPosts = foundPosts
            if self.topPosts.isEmpty && !recommendedIDs.isEmpty {
                 print("WatchApp: Recommended Post IDs were found, but posts not present in local SwiftData. Data might not be synced via App Group yet, or posts are older than what's synced/queried by @Query.")
            }
        }
        
        isLoading = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // This preview will likely not have a fully configured RecommendationService
        // or a shared App Group data store, so it might show empty/loading state.
        // For meaningful previews, mock data or a mock RecommendationService would be needed.
        ContentView()
            // Example of how to set up a model container for previews if needed:
            // .modelContainer(for: [Post.self, Account.self, /* other models */], inMemory: true)
    }
}
