import SwiftUI

struct RecommendedTimelineView: View {
    @StateObject var viewModel: RecommendedTimelineViewModel
    // For navigation to profile views.
    // This might be handled by a NavigationCoordinator or by passing a closure.
    // For now, we'll use the viewModel's internal NavigationPath.
    
    // Initializer allowing injection of all necessary services.
    // In a real app, these might come from an AppServices container.
    init(timelineService: TimelineServiceProtocol,
         postActionService: PostActionServiceProtocol,
         recommendationService: RecommendationService = .shared) {
        _viewModel = StateObject(wrappedValue: RecommendedTimelineViewModel(
            timelineService: timelineService,
            recommendationService: recommendationService,
            postActionService: postActionService
        ))
    }

    var body: some View {
        // The view model's navigationPath will be used by NavigationStack
        // if PostView triggers navigation to a User profile.
        NavigationStack(path: $viewModel.navigationPath) {
            List {
                // --- "For You" Section ---
                Section { // Removed custom header to use default List section styling
                    if viewModel.isLoading && viewModel.forYouPosts.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, alignment: .center)
                    } else if !viewModel.isLoading && viewModel.forYouPosts.isEmpty && viewModel.chronologicalPosts.isEmpty {
                        Text("No recommendations available yet. Interact with posts to build recommendations.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center) // Center text
                    } else if !viewModel.forYouPosts.isEmpty {
                        ForEach(viewModel.forYouPosts) { post in
                            PostViewWrapper(post: post,
                                            viewModel: viewModel,
                                            recommendationService: viewModel.recommendationService, // Pass it down
                                            viewProfileAction: navigateToProfile)
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 4) // Consistent padding
                        }
                    } else if !viewModel.isLoading && !viewModel.chronologicalPosts.isEmpty {
                         Text("No specific recommendations for you right now. Check out all posts below!")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center) // Center text
                    }
                } header: {
                    Text("For You").font(.headline) // Standard header
                }

                // --- "All Posts" (Chronological) Section ---
                Section { // Removed custom header
                    if viewModel.isLoading && viewModel.chronologicalPosts.isEmpty && viewModel.forYouPosts.isEmpty {
                       // Only show this loading if "For You" is also empty and loading.
                       // Otherwise, the main loading indicator in "For You" covers it.
                       // ProgressView().frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.chronologicalPosts.isEmpty && !viewModel.isLoading {
                        Text("No posts found on your timeline.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center) // Center text
                    } else {
                        ForEach(viewModel.chronologicalPosts) { post in
                            // Decide if chronological posts should also show interest scores
                            // For now, let's keep them simple, or you can use PostViewWrapper here too
                            // If using PostViewWrapper, ensure it doesn't fetch score if not needed or if score is 0
                            PostViewWrapper(post: post, // Using wrapper for chronological too for consistency
                                            viewModel: viewModel,
                                            recommendationService: viewModel.recommendationService,
                                            viewProfileAction: navigateToProfile,
                                            fetchInterestScore: true) // Control if score should be fetched
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreContentIfNeeded(currentItem: post, section: .chronological)
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 4) // Consistent padding
                        }
                        if viewModel.isLoading && !viewModel.chronologicalPosts.isEmpty { // Loading more indicator
                            ProgressView().frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                } header: {
                    Text("All Posts").font(.headline) // Standard header
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Recommended")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.refreshTimeline() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if viewModel.forYouPosts.isEmpty && viewModel.chronologicalPosts.isEmpty {
                    await viewModel.initialLoad()
                }
            }
            .alert(item: $viewModel.alertError) { appError in
                Alert(title: Text("Error"), message: Text(appError.message), dismissButton: .default(Text("OK")))
            }
            .refreshable {
                await viewModel.refreshTimeline()
            }
            // NavigationDestination for User profiles, if PostView uses viewModel.navigateToProfile
            .navigationDestination(for: User.self) { user in
                // Assuming ProfileView exists and takes a User object
                // Also ProfileView would need its own ViewModel, typically injected or created.
                // This part depends on how ProfileView is structured and how its dependencies are provided.
                // For now, a placeholder or direct instantiation if simple enough.
                // ProfileView(user: user).environmentObject(AppServices.shared.profileViewModel) // Example
                Text("Profile View for \(user.username)") // Placeholder
            }
        }
    }
    
    // Helper to navigate to profile
    private func navigateToProfile(_ user: User) {
        // This will trigger the .navigationDestination in NavigationStack
        viewModel.navigationPath.append(user)
        print("Attempting to navigate to profile: \(user.username)")
    }
}


// Wrapper View to handle interest score fetching for each PostView instance
struct PostViewWrapper: View {
    let post: Post
    @ObservedObject var viewModel: RecommendedTimelineViewModel // Main VM for actions
    let recommendationService: RecommendationService // Passed for fetching score
    var viewProfileAction: (User) -> Void
    let fetchInterestScore: Bool // Determine if score should be fetched

    @State private var interestScore: Double = 0.0
    // Threshold could also be defined here or passed, for now PostView defines its own display threshold

    init(post: Post,
         viewModel: RecommendedTimelineViewModel,
         recommendationService: RecommendationService,
         viewProfileAction: @escaping (User) -> Void,
         fetchInterestScore: Bool = true) { // Default to true for "For You"
        self.post = post
        self.viewModel = viewModel
        self.recommendationService = recommendationService
        self.viewProfileAction = viewProfileAction
        self.fetchInterestScore = fetchInterestScore
    }

    var body: some View {
        PostView(post: post,
                 viewModel: viewModel, // Pass RecommendedTimelineViewModel as it conforms to PostViewActionsDelegate
                 viewProfileAction: viewProfileAction,
                 interestScore: interestScore) // Pass the fetched score
            .task {
                if fetchInterestScore { // Only fetch if requested (e.g., for "For You" section)
                    self.interestScore = await recommendationService.getInterestScore(
                        for: post.id,
                        authorAccountID: post.account?.id,
                        tags: post.tags?.compactMap { $0.name } // Assuming Tag has 'name'
                    )
                }
            }
    }
}


// Define a protocol that PostView can use for its actions,
// and make RecommendedTimelineViewModel conform to it.
// This is a more robust way than casting or assuming specific ViewModel types.
protocol PostViewActionsDelegate: ObservableObject {
    // Properties PostView might need for displaying comment sheets, etc.
    var selectedPostForComments: Post? { get set }
    var showingCommentSheet: Bool { get set }
    var commentText: String { get set }
    
    // Methods PostView calls for actions
    func toggleLike(for post: Post) async
    func toggleRepost(for post: Post) async
    func comment(on post: Post, content: String) async
    func showComments(for post: Post) async
    
    // Method for individual post loading state
    func isLoading(for post: Post) -> Bool
    
    // Method for navigation to profile
    func navigateToProfile(_ user: User) async

    // Placeholder for current user ID, for interaction logging within PostView itself if necessary,
    // though it's better if interaction logging is centralized in the ViewModel's action methods.
    var currentUserAccountID: String? { get }
}

// Make RecommendedTimelineViewModel conform to this protocol
extension RecommendedTimelineViewModel: PostViewActionsDelegate {
    // Accessor for RecommendationService, needed by PostViewWrapper if not passed directly
    // This is already a property of RecommendedTimelineViewModel
    // var recommendationServiceForPostView: RecommendationService { self.recommendationService }

    // currentUserAccountID is already a private var with a placeholder.
    // Make it accessible via the protocol if PostView needs it directly
    // (though better if actions in VM use their internal currentUserAccountID).
    // For now, the placeholder in RecommendedTimelineViewModel will be used by its own action methods.
}

// Modify PostView to use this protocol
// Example (conceptual, actual modification of PostView would be a separate step/file):
/*
 struct PostView<ViewModel: PostViewActionsDelegate>: View {
     let post: Post
     @ObservedObject var viewModel: ViewModel
     var viewProfileAction: (User) -> Void // This might become redundant if viewModel handles navigation
     // ... rest of PostView body ...
 }
*/
// For this subtask, we will assume PostView can accept RecommendedTimelineViewModel directly
// as its 'viewModel' because RecommendedTimelineViewModel now implements the necessary methods.
// This avoids modifying PostView in this step, but the protocol approach is cleaner.

#if DEBUG
// Define mock services for Previews
struct MockTimelineService: TimelineServiceProtocol {
    func WorkspaceHomeTimeline(maxId: String?, minId: String?, limit: Int?) async throws -> [Post] {
        // Create a few mock posts
        let account = Account(id: "mockAcc1", username: "mockUser", acct: "mockUser@example.com", display_name: "Mock User", avatar: "https://example.com/avatar.png", header: "", followers_count: 10, following_count: 5, statuses_count: 2, note: "Mock bio")
        return [
            Post(id: "fyp1", content: "For You Post 1! #cool", createdAt: Date().addingTimeInterval(-300), account: account, tags: [Tag(name: "cool", url: "")]),
            Post(id: "fyp2", content: "For You Post 2! #awesome", createdAt: Date().addingTimeInterval(-600), account: account, tags: [Tag(name: "awesome", url: "")])
        ]
    }
}

struct MockPostActionService: PostActionServiceProtocol {
    func toggleLike(postID: String, isCurrentlyFavourited: Bool) async throws -> Post? { return nil }
    func toggleRepost(postID: String, isCurrentlyReblogged: Bool) async throws -> Post? { return nil }
    func comment(postID: String, content: String) async throws -> Post? { return nil }
}

// Define a PreviewTag struct that matches what Post expects, if not already globally available
// This is based on the assumption from previous steps (e.g., Post.swift uses [PreviewTag]?)
struct PreviewTag: Codable, Hashable, Identifiable { // Add Identifiable if used in ForEach directly
    var id: String { name } // Assuming name is unique for Identifiable
    let name: String
    let url: String? // Optional URL
}


struct RecommendedTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendedTimelineView(
            timelineService: MockTimelineService(),
            postActionService: MockPostActionService()
            // recommendationService can use the default .shared for previews if it doesn't make real network calls on init
        )
        // Example of how to provide a specific RecommendationService if needed for previews
        // .environmentObject(RecommendationService.shared) // If PostViewWrapper used @EnvironmentObject
    }
}
#endif
