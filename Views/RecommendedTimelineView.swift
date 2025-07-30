//
//  RecommendedTimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  (REVISED & FIXED)

import SwiftUI

struct RecommendedTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel // For navigation and UI state
    @Environment(TimelineProvider.self) private var timelineProvider

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            List {
                // "For You" Section
                Section(header: Text("For You").font(.headline)) {
                    if timelineProvider.isLoading && timelineProvider.recommendedForYouPosts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !timelineProvider.isLoading && timelineProvider.recommendedForYouPosts.isEmpty && timelineProvider.recommendedChronologicalPosts.isEmpty {
                        Text("No recommendations available yet. Interact with posts to build recommendations.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !timelineProvider.recommendedForYouPosts.isEmpty {
                        ForEach(timelineProvider.recommendedForYouPosts) { post in
                            PostViewWrapper(
                                post: post,
                                viewProfileAction: navigateToProfile
                            )
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                        }
                    } else if !timelineProvider.isLoading && !timelineProvider.recommendedChronologicalPosts.isEmpty {
                        Text("No specific recommendations for you right now. Check out all posts below!")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                // "All Posts" Section
                Section(header: Text("All Posts").font(.headline)) {
                    if timelineProvider.isLoading && timelineProvider.recommendedChronologicalPosts.isEmpty && timelineProvider.recommendedForYouPosts.isEmpty {
                        // Show nothing, or optionally a progress indicator here
                    } else if timelineProvider.recommendedChronologicalPosts.isEmpty && !timelineProvider.isLoading {
                        Text("No posts found on your timeline.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(timelineProvider.recommendedChronologicalPosts) { post in
                            PostViewWrapper(
                                post: post,
                                viewProfileAction: navigateToProfile,
                                fetchInterestScore: true
                            )
                            .onAppear {
                                if post.id == timelineProvider.recommendedChronologicalPosts.last?.id && !timelineProvider.isFetchingMore {
                                    Task {
                                        await timelineProvider.fetchMoreTimeline(for: .recommended)
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                        }
                        if timelineProvider.isFetchingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Recommended")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await timelineProvider.refreshTimeline(for: .recommended) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if timelineProvider.recommendedForYouPosts.isEmpty && timelineProvider.recommendedChronologicalPosts.isEmpty {
                    await timelineProvider.initializeTimelineData(for: .recommended)
                }
            }
            .alert(item: $timelineProvider.alertError) { appError in
                Alert(title: Text("Error"), message: Text(appError.message), dismissButton: .default(Text("OK")))
            }
            .refreshable {
                await timelineProvider.refreshTimeline(for: .recommended)
            }
            // Navigation destination for User
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
        }
    }

    private func navigateToProfile(_ user: User) {
        viewModel.navigationPath.append(user)
        print("Attempting to navigate to profile: \(user.username)")
    }
}

// Wrapper View to handle interest score fetching
struct PostViewWrapper: View {
    let post: Post
    var viewProfileAction: (User) -> Void
    let fetchInterestScore: Bool

    @Environment(RecommendationService.self) private var recommendationService
    @State private var interestScore: Double = 0.0

    init(post: Post,
         viewProfileAction: @escaping (User) -> Void,
         fetchInterestScore: Bool = true) {
        self.post = post
        self.viewProfileAction = viewProfileAction
        self.fetchInterestScore = fetchInterestScore
    }

    var body: some View {
        PostView(
            post: post,
            viewProfileAction: viewProfileAction,
            interestScore: interestScore
        )
        .task {
            if fetchInterestScore {
                self.interestScore = await recommendationService.getInterestScore(
                    for: post.id,
                    authorAccountID: post.account?.id,
                    tags: post.tags?.compactMap { $0.name }
                )
            }
        }
    }
}
