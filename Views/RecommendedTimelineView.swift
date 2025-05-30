//
//  RecommendedTimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  (REVISED & FIXED)

import SwiftUI

struct RecommendedTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel

    // Initializer receives the already-created ViewModel from a parent view.
    init(viewModel: TimelineViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            List {
                // "For You" Section
                Section(header: Text("For You").font(.headline)) {
                    if viewModel.isLoading && viewModel.recommendedForYouPosts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !viewModel.isLoading && viewModel.recommendedForYouPosts.isEmpty && viewModel.recommendedChronologicalPosts.isEmpty {
                        Text("No recommendations available yet. Interact with posts to build recommendations.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !viewModel.recommendedForYouPosts.isEmpty {
                        ForEach(viewModel.recommendedForYouPosts) { post in
                            PostViewWrapper(
                                post: post,
                                viewModel: viewModel,
                                recommendationService: viewModel.recommendationService,
                                viewProfileAction: navigateToProfile
                            )
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                        }
                    } else if !viewModel.isLoading && !viewModel.recommendedChronologicalPosts.isEmpty {
                        Text("No specific recommendations for you right now. Check out all posts below!")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                // "All Posts" Section
                Section(header: Text("All Posts").font(.headline)) {
                    if viewModel.isLoading && viewModel.recommendedChronologicalPosts.isEmpty && viewModel.recommendedForYouPosts.isEmpty {
                        // Show nothing, or optionally a progress indicator here
                    } else if viewModel.recommendedChronologicalPosts.isEmpty && !viewModel.isLoading {
                        Text("No posts found on your timeline.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(viewModel.recommendedChronologicalPosts) { post in
                            PostViewWrapper(
                                post: post,
                                viewModel: viewModel,
                                recommendationService: viewModel.recommendationService,
                                viewProfileAction: navigateToProfile,
                                fetchInterestScore: true
                            )
                            .onAppear {
                                if post.id == viewModel.recommendedChronologicalPosts.last?.id && !viewModel.isFetchingMore {
                                    Task {
                                        await viewModel.fetchMoreTimeline()
                                    }
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 4)
                        }
                        if viewModel.isFetchingMore {
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
                        Task { await viewModel.refreshTimeline() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if viewModel.recommendedForYouPosts.isEmpty && viewModel.recommendedChronologicalPosts.isEmpty {
                    await viewModel.initializeTimelineData()
                }
            }
            .alert(item: $viewModel.alertError) { appError in
                Alert(title: Text("Error"), message: Text(appError.message), dismissButton: .default(Text("OK")))
            }
            .refreshable {
                await viewModel.refreshTimeline()
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
    @ObservedObject var viewModel: TimelineViewModel
    let recommendationService: RecommendationService
    var viewProfileAction: (User) -> Void
    let fetchInterestScore: Bool

    @State private var interestScore: Double = 0.0

    init(post: Post,
         viewModel: TimelineViewModel,
         recommendationService: RecommendationService,
         viewProfileAction: @escaping (User) -> Void,
         fetchInterestScore: Bool = true) {
        self.post = post
        self.viewModel = viewModel
        self.recommendationService = recommendationService
        self.viewProfileAction = viewProfileAction
        self.fetchInterestScore = fetchInterestScore
    }

    var body: some View {
        PostView(
            post: post,
            viewModel: viewModel,
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
