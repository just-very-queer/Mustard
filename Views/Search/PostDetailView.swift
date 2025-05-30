//
//  PostDetailView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct PostDetailView: View {
    let post: Post // The outer Post object, which might be a reblog
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showDetail: Bool // Used to dismiss this view when presented as a sheet

    @State private var isCommentSectionExpanded: Bool = true // Remains true for detail view
    @State private var commentInputText: String = ""
    
    // State for fetched replies specific to this detail view
    @State private var detailedReplies: [Post]? = nil
    @State private var isLoadingReplies: Bool = false

    // Helper to determine which post's details to display (original or reblogged)
    private var displayPost: Post {
        return post.reblog ?? post
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Display the main post
                        PostView(
                            post: post, // Pass the original post; PostView will handle displayPost internally
                            viewModel: viewModel,
                            viewProfileAction: { user in
                                viewModel.navigateToProfile(user)
                                // If presented modally, navigating might require dismissing the sheet first
                                // or using a more complex navigation setup if full navigation stack is needed in sheet.
                                print("Profile tapped in Detail View: \(user.username)")
                            },
                            interestScore: 0.0 // Or fetch if relevant for the main post in detail view
                        )
                        .padding(.bottom, 10)

                        // Section for replies to the main post
                        ExpandedCommentsSection(
                            post: displayPost, // This is the post being replied to
                            isExpanded: $isCommentSectionExpanded, // Should always be true here
                            commentText: $commentInputText, // Text for new reply to displayPost
                            viewModel: viewModel,
                            repliesToDisplay: detailedReplies,
                            isLoadingReplies: $isLoadingReplies,
                            currentDetailPost: displayPost // Pass the post being detailed
                        )
                    }
                }
            }
            .navigationTitle("Post Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDetail = false // Dismisses the sheet
                    }
                }
            }
            .task(id: displayPost.id) { // Reload replies if the displayPost changes
                await loadReplies(forPost: displayPost)
            }
        }
    }
    
    private func loadReplies(forPost: Post) async {
        isLoadingReplies = true
        self.detailedReplies = nil // Clear previous replies
        
        if let context = await viewModel.fetchContext(for: forPost) {
            self.detailedReplies = context.descendants
        } else {
            self.detailedReplies = [] // Default to empty on error or no context
        }
        isLoadingReplies = false
    }
}

struct ExpandedCommentsSection: View {
    let post: Post // The post to which these comments are replies (displayPost from parent)
    @Binding var isExpanded: Bool
    @Binding var commentText: String // For writing a new reply to `post`
    @ObservedObject var viewModel: TimelineViewModel
    let repliesToDisplay: [Post]?
    @Binding var isLoadingReplies: Bool
    
    let currentDetailPost: Post // The post for which this comment section is being shown

    // State for presenting a tapped comment in its own PostDetailView
    @State private var selectedCommentForDetailSheet: Post? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.horizontal)
            
            Text("Replies")
                .font(.headline)
                .padding(.horizontal)
                .foregroundColor(.primary)
            
            if isLoadingReplies {
                ProgressView("Loading replies...")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let currentReplies = repliesToDisplay, !currentReplies.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(currentReplies) { reply in
                        // Each reply is a Post object
                        VStack(alignment: .leading, spacing: 0) {
                            // Display the reply as a PostView
                            // This makes each comment look like a full post, with its own actions, content, etc.
                            PostView(
                                post: reply, // The reply itself
                                viewModel: viewModel,
                                viewProfileAction: { user in
                                    viewModel.navigateToProfile(user)
                                },
                                interestScore: 0.0 // Or fetch interest score for the reply if needed
                            )
                            .contentShape(Rectangle()) // Make the whole PostView tappable
                            .onTapGesture {
                                // When a reply is tapped, set it to be shown in a new detail sheet
                                self.selectedCommentForDetailSheet = reply
                            }
                        }
                        .padding(.vertical, 5) // Add some spacing between replies
                        
                        Divider().padding(.leading, 16) // Indent divider slightly
                    }
                }
                // This sheet presents PostDetailView for a tapped reply (comment)
                .sheet(item: $selectedCommentForDetailSheet) { tappedReply in
                    // Pass the tappedReply to a new PostDetailView instance
                    // showDetail binding here controls the presentation of THIS sheet
                    PostDetailView(
                        post: tappedReply,
                        viewModel: viewModel,
                        showDetail: Binding( // This binding controls the newly presented sheet
                            get: { selectedCommentForDetailSheet != nil },
                            set: { if !$0 { selectedCommentForDetailSheet = nil } }
                        )
                    )
                }
            } else {
                Text("No replies yet.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
            
            // Input field for adding a new reply to the `post` (displayPost from parent)
            HStack {
                TextField("Add a reply to @\(post.account?.username ?? "user")", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button {
                    viewModel.comment(on: post, content: commentText) // 'post' here is the one being replied to
                    commentText = "" // Clear input after sending
                    // Optionally, trigger a refresh of replies for the `currentDetailPost`
                    Task {
                        // This reloads replies for the main post this comment section belongs to
                        if (await viewModel.fetchContext(for: currentDetailPost)) != nil {
                             // This state update might need to be passed up or handled via a shared mechanism
                             // For simplicity, assuming viewModel handles updating its own state which parent observes
                             // Or, if detailedReplies is directly mutable from parent:
                             // parent.detailedReplies = context.descendants (this is not how @State works directly)
                             // A direct refresh function call on parent might be cleaner or a callback.
                             // For now, let's assume parent PostDetailView's .task(id: displayPost.id) will re-fetch
                             // if displayPost's relevant properties (like repliesCount) change or if we explicitly trigger.
                             // A simple way is to just re-call the loadReplies on the viewModel for the *currentDetailPost*.
                            // This part can get complex depending on how state flows.
                            // The loadReplies in PostDetailView should be sufficient if it's re-triggered.
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
        }
        .padding(.vertical, 10)
        .dynamicTypeSize(.medium)
    }
}
