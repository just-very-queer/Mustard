//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//


import SwiftUI
import SwiftData

struct ContentView: View {
    // RecommendationService is configured in MustardWatchApp's init.
    // We can access it as a shared instance.
    let recommendationService = RecommendationService.shared
    
    @State private var topPosts: [Post] = []
    @State private var isLoading: Bool = true

    // Query to fetch Post objects by ID.
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
                        ForEach(Array(topPosts.prefix(3))) { post in // Show top 3
                            VStack(alignment: .leading, spacing: 4) {
                                if let account = post.account {
                                    // FIX: Removed redundant '?? "Unknown Author"'
                                    Text(account.display_name ?? account.username)
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
        isLoading = true
        let recommendedIDs = await recommendationService.topRecommendations(limit: 5)
        
        if recommendedIDs.isEmpty && !allPostsInDatabase.isEmpty {
            self.topPosts = []
            print("WatchApp: No specific recommendations found. TopPosts will be empty.")
        } else if recommendedIDs.isEmpty && allPostsInDatabase.isEmpty {
            self.topPosts = []
            print("WatchApp: No recommendations and no posts in local database.")
        }
        else {
            var foundPosts: [Post] = []
            for idToFind in recommendedIDs {
                if let post = allPostsInDatabase.first(where: { $0.id == idToFind }) {
                    foundPosts.append(post)
                }
                if foundPosts.count >= 3 {
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
