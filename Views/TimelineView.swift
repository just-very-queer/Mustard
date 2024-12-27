//
//  TimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var viewModel: TimelineViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if viewModel.posts.isEmpty {
                // Show a message if no posts are available
                Text("No posts available.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // Display the timeline posts
                List(viewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostRowView(post: post)
                            .environmentObject(viewModel)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.fetchTimeline()
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
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
        .alert(item: $viewModel.alertError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            Task {
                await viewModel.fetchTimeline()
            }
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "mockAccessToken123"
        )
        
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
        
        let mockService = MockMastodonService(shouldSucceed: true, mockPosts: [samplePost])
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.posts = [samplePost]

        return NavigationStack {
            TimelineView()
                .environmentObject(viewModel)
        }
    }
}

