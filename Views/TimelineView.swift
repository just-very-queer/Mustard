//
//  TimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct TimelineView: View {
    // Access the TimelineViewModel from the environment
    @EnvironmentObject var viewModel: TimelineViewModel

    var body: some View {
        VStack {
            // Display a loading indicator when fetching data
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                // Display the list of posts
                List(viewModel.posts) { post in
                    // Each post navigates to its detail view
                    NavigationLink(destination: PostDetailView(post: post)) {
                        // Display the post row
                        PostRowView(post: post)
                            .environmentObject(viewModel)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    // Allow pull-to-refresh to fetch the latest timeline
                    await viewModel.fetchTimeline()
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            // Add a refresh button in the navigation bar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.fetchTimeline()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Timeline")
            }
        }
        // Present an alert if there's an error
        .alert(item: $viewModel.alertError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample account
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "mockAccessToken123"
        )
        
        // Create a sample post
        let samplePost = Post(
            id: "1",
            content: "<p>Hello, world!</p>",
            createdAt: Date(),
            account: sampleAccount,
            mediaAttachments: [],
            isFavourited: false,
            isReblogged: false,
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0
        )
        
        // Initialize the MockMastodonService with the sample post and shouldSucceed: true
        let mockService = MockMastodonService(shouldSucceed: true, mockPosts: [samplePost])
        
        // Initialize the TimelineViewModel with the mock service
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.posts = [samplePost]
        
        return NavigationStack {
            TimelineView()
                .environmentObject(viewModel)
        }
    }
}

