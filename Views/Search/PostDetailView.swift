//
//  PostDetailView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct PostDetailView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel  // Use the central TimelineViewModel
    @Binding var showDetail: Bool // To control the presentation of this detail view

    // Local state for managing the comment section within this detail view
    @State private var isCommentSectionExpanded: Bool = true // Keep comments expanded by default in detail view
    @State private var commentInputText: String = "" // Text input specifically for this detail view

    // State variables for fetching context
    @State private var isLoadingContext: Bool = false
    @State private var fetchedReplies: [Post] = []
    @State private var contextError: String? = nil // Store error message as String

    var body: some View {
        NavigationView { // Wrap in NavigationView for a potential title and toolbar items
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) { // Use spacing 0 if subviews handle padding
                        // Use the REVISED PostView
                        PostView(
                            post: post,
                            viewModel: viewModel, // Pass the TimelineViewModel
                            viewProfileAction: { user in
                                // Handle profile navigation, maybe dismiss this sheet first?
                                // Option 1: Use viewModel navigation (if it handles path correctly)
                                 viewModel.navigateToProfile(user)
                                // Option 2: Dismiss and notify parent (more complex)
                                // showDetail = false // Dismiss first? Needs coordination.
                                print("Profile tapped in Detail View: \(user.username)")
                            },
                            interestScore: 0.0 // FIX: Added missing interestScore with a default value
                        )
                        .padding(.bottom, 10) // Add padding below the main post

                        // Display Loading/Error or Comments Section
                        if isLoadingContext {
                            ProgressView("Loading comments...")
                                .padding()
                        } else if let errorMsg = contextError {
                            Text("Error: \(errorMsg)")
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            // ExpandedCommentsSection for this detail view
                            // This will be updated in the next step to use fetchedReplies
                            ExpandedCommentsSection(
                                post: post, // Keep post for new comment context
                                actualReplies: fetchedReplies, // Pass fetched replies (will require ExpandedCommentsSection modification)
                                isExpanded: $isCommentSectionExpanded, // Use local state for expansion control if needed
                                commentText: $commentInputText, // Use local state for text input
                                viewModel: viewModel // Pass the viewModel for posting action
                            )
                        }
                    }
                }
                // Removed the overlaying close button, use NavigationBarItem instead
            }
            .navigationTitle("Post Details") // Add a title
            .navigationBarTitleDisplayMode(.inline)
            .task(id: post.id) { // Re-fetch if the post ID changes
                await loadPostContext()
            }
            // .toolbar { // Toolbar removed as "Done" button is the only item
            //     // Add a Done button to dismiss the view
            //     ToolbarItem(placement: .navigationBarTrailing) {
            //         Button("Done") {
            //             showDetail = false
            //         }
            //     }
            // }
        }
        // Removed background and edgesIgnoringSafeArea, let NavigationView handle it
    }

    private func loadPostContext() async {
        isLoadingContext = true
        contextError = nil
        fetchedReplies = [] // Clear previous replies

        do {
            // Call fetchContextForPost via the viewModel
            let context = try await viewModel.fetchContextForPost(postId: post.id)
            self.fetchedReplies = context.descendants
        } catch let error as AppError {
            self.contextError = error.message
            // Log detailed error if needed: print(error.localizedDescription)
        } catch {
            self.contextError = "Failed to load comments: \(error.localizedDescription)"
            // Log detailed error: print(error.localizedDescription)
        }
        isLoadingContext = false
    }
}
