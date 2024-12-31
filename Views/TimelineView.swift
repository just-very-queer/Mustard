//
//  TimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        VStack {
            if timelineViewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if timelineViewModel.posts.isEmpty {
                Text("No posts available.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(timelineViewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostRowView(post: post)
                        // Removed: .environmentObject(timelineViewModel)
                        // PostRowView already inherits the environment object
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await timelineViewModel.fetchTimeline()
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await timelineViewModel.fetchTimeline()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Timeline")
            }
        }
        .alert(item: $timelineViewModel.alertError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            Task {
                await timelineViewModel.fetchTimeline()
            }
        }
    }
}

// MARK: - Preview
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize Mock Service for Preview
        let mockService = MockMastodonService(shouldSucceed: true, mockPosts: [
            Post(
                id: "1",
                content: "<p>Hello, world!</p>",
                createdAt: Date(),
                account: Account(
                    id: "a1",
                    username: "user1",
                    displayName: "User One",
                    avatar: URL(string: "https://example.com/avatar1.png")!,
                    acct: "user1",
                    instanceURL: URL(string: "https://mastodon.social")!,
                    accessToken: "mockAccessToken123"
                ),
                mediaAttachments: [],
                isFavourited: false,
                isReblogged: false,
                reblogsCount: 0,
                favouritesCount: 0,
                repliesCount: 0
            )
        ])
        
        // Initialize Model Container with Required Models
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let modelContext = container.mainContext

        // Initialize ViewModels with Mock Service and Context
        let accountsViewModel = AccountsViewModel(mastodonService: mockService, modelContext: modelContext)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)

        // Populate ViewModels with Mock Data
        timelineViewModel.posts = mockService.mockPosts
        timelineViewModel.isLoading = false
        timelineViewModel.alertError = nil

        return NavigationView {
            TimelineView()
                .environmentObject(timelineViewModel)
                .environmentObject(authViewModel)
                .environmentObject(accountsViewModel) // Ensure all necessary environment objects are injected
                .modelContainer(container)
        }
    }
}

