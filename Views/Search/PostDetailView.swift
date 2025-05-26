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
                            }
                        )
                        .padding(.bottom, 10) // Add padding below the main post

                        // ExpandedCommentsSection for this detail view
                        ExpandedCommentsSection(
                            post: post,
                            isExpanded: $isCommentSectionExpanded, // Use local state for expansion control if needed
                            commentText: $commentInputText, // Use local state for text input
                            viewModel: viewModel // Pass the viewModel for posting action
                        )
                    }
                }
                // Removed the overlaying close button, use NavigationBarItem instead
            }
            .navigationTitle("Post Details") // Add a title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Add a Done button to dismiss the view
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDetail = false
                    }
                }
            }
        }
        // Removed background and edgesIgnoringSafeArea, let NavigationView handle it
    }
}
