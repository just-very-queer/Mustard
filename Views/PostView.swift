//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//


import SwiftUI
import LinkPresentation
import SafariServices
import SwiftSoup // If needed for HTML parsing in subviews

// MARK: - PostView (Main View)
struct PostView: View {
    // Properties
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel // Use the ViewModel directly
    var viewProfileAction: (User) -> Void // Keep for context-dependent navigation

    // Local UI State
    @State private var showFullText = false
    @State private var showImageViewer = false
    @State private var showBrowserView = false // Assuming this uses post.url

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // User Header - Pass profile navigation action
            UserHeaderView(post: post, viewProfileAction: viewProfileAction)

            // Content
            PostContentView(post: post, showFullText: $showFullText)

            // Media attachments - Trigger local state for viewer
            MediaAttachmentView(post: post, onImageTap: {
                self.showImageViewer.toggle()
            })

            // Post actions - Directly call ViewModel methods
            PostActionsViewRevised(post: post, viewModel: viewModel)
                .padding(.top, 5)

            // Loading Indicator - Check state from ViewModel
            if viewModel.isLoading(for: post) {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground)) // Use adaptive background
        .cornerRadius(16)
        .padding(.horizontal, 8)
        .shadow(color: .primary.opacity(0.05), radius: 8, x: 0, y: 3)
        .dynamicTypeSize(.medium)
        // Sheet for FullScreenImageView (Uses local state)
        .sheet(isPresented: $showImageViewer) {
            // Assuming first attachment is the one to show fullscreen
            if let imageURL = post.mediaAttachments.first?.url {
                FullScreenImageView(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
        // Sheet for WebView (Uses local state and post data)
        .sheet(isPresented: $showBrowserView) {
            // Assuming post.url contains the link to show
            if let urlString = post.url, let url = URL(string: urlString) {
                 SafariView(url: url) // Assumes SafariView exists
            }
        }
        // Alert for errors (Handled by parent view using viewModel.alertError)
    }
}

// MARK: - Revised PostActionsView
struct PostActionsViewRevised: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel // Inject ViewModel

    var body: some View {
        HStack {
            // Like Button
            Button {
                viewModel.toggleLike(for: post)
            } label: {
                Image(systemName: post.isFavourited ? "heart.fill" : "heart")
                    .foregroundColor(post.isFavourited ? .red : .gray)
                Text("\(post.favouritesCount)") // Display count
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle for better layout control

            Spacer()

            // Repost Button
            Button {
                viewModel.toggleRepost(for: post)
            } label: {
                Image(systemName: post.isReblogged ? "arrow.2.squarepath" : "arrow.2.squarepath") // Use consistent icon
                    .foregroundColor(post.isReblogged ? .green : .gray)
                 Text("\(post.reblogsCount)") // Display count
                     .font(.caption)
                     .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Comment Button - Shows sheet via ViewModel
            Button {
                viewModel.showComments(for: post)
            } label: {
                Image(systemName: "bubble.left")
                    .foregroundColor(.gray)
                Text("\(post.repliesCount)") // Display count
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // More Options Button (Example: Share)
            if let urlString = post.url, let url = URL(string: urlString) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.gray)
                }
            } else {
                // Provide a disabled or different button if no URL
                 Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal) // Add padding for better spacing
    }
}

// MARK: - Subviews (Keep relevant subviews like PostContentView, MediaAttachmentView, UserHeaderView)

// Example: Keep PostContentView as is
struct PostContentView: View {
    let post: Post
    @Binding var showFullText: Bool

    // State to hold the computed attributed string
    @State private var displayedAttributedString: AttributedString? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Display the computed AttributedString (or fallback)
            if let attrString = displayedAttributedString {
                Text(attrString)
                    .font(.body) // Apply font modifier here if needed
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary) // Apply color here
                    .padding(.horizontal)
            } else {
                // Fallback to plain text while loading or if conversion fails
                Text(post.content) // Or use HTMLUtils.convertHTMLToPlainText
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    // Optionally show a placeholder or spinner while loading state
            }

            // "Show More" button (logic remains the same)
            // Consider content length check based on plain text?
            let plainText = HTMLUtils.convertHTMLToPlainText(html: post.content)
            if !showFullText && plainText.count > 200 { // Example condition using plain text length
                 ShowMoreButton(showFullText: $showFullText)
            }
        }
        .padding(.vertical, 5)
        // Use .task to compute the AttributedString when post.content changes
        // This runs asynchronously and updates the @State variable, triggering a valid view update
        .task(id: post.content) { // Re-run when post.content changes
             // Perform the conversion asynchronously
             // Add a small delay if needed to ensure it runs after initial layout pass
             // try? await Task.sleep(for: .milliseconds(10))
             self.displayedAttributedString = HTMLUtils.attributedStringFromHTML(htmlString: post.content)
        }
        // Or use .onChange if you prefer (though .task(id:) is often cleaner for this)
        /*
        .onChange(of: post.content) { _, newContent in
            self.displayedAttributedString = HTMLUtils.attributedStringFromHTML(htmlString: newContent)
        }
        .onAppear { // Initial calculation on appear
             if displayedAttributedString == nil {
                 self.displayedAttributedString = HTMLUtils.attributedStringFromHTML(htmlString: post.content)
             }
        }
        */
    }
}

// ShowMoreButton remains the same
struct ShowMoreButton: View {
    @Binding var showFullText: Bool

    var body: some View {
        Button(action: { showFullText.toggle() }) {
            Text(showFullText ? "Show Less" : "Show More")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// UserHeaderView - Assuming viewProfileAction remains for flexibility
struct UserHeaderView: View {
    let post: Post
    var viewProfileAction: (User) -> Void

    var body: some View {
        HStack {
            AvatarView(url: post.account?.avatar, size: 44)
                .onTapGesture {
                    if let user = post.account?.toUser() {
                        viewProfileAction(user)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.account?.display_name ?? post.account?.username ?? "Unknown User")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("@\(post.account?.acct ?? "unknown")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
            Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.top, 5)
    }
}

// MARK: - ExpandedCommentsSection (Re-declared here)
// This struct defines the view for displaying comments and adding a new one.
// It's used within PostDetailView or potentially the comment sheet shown by TimelineViewModel.
struct ExpandedCommentsSection: View {
    let post: Post // The post whose comments are being shown
    @Binding var isExpanded: Bool // To control visibility (might not be needed if always shown in DetailView)
    @Binding var commentText: String // Bound to the text field input
    @ObservedObject var viewModel: TimelineViewModel // To handle posting the comment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Separator
            Divider().padding(.horizontal)

            // Title
            Text("Replies") // Changed from "Comments" to "Replies" to match Mastodon term
                .font(.headline)
                .padding(.horizontal)
                .foregroundColor(.primary)

            // List existing replies (assuming post.replies is populated)
            // Note: The `Post` model needs to correctly decode/fetch replies.
            // If `post.replies` is nil or empty, this ForEach won't display anything.
            if let replies = post.replies, !replies.isEmpty {
                ForEach(replies) { reply in
                    VStack(alignment: .leading, spacing: 5) {
                        // Use UserHeaderView for consistency
                        UserHeaderView(post: reply, viewProfileAction: { user in
                            // Decide how to handle profile taps from replies
                            // Option 1: Use the viewModel's navigation
                             viewModel.navigateToProfile(user)
                            // Option 2: Could potentially dismiss the detail view and navigate
                        })
                        // Display reply content
                        PostContentView(post: reply, showFullText: .constant(true)) // Always show full text for replies

                    }
                    .padding(.bottom, 5)
                    Divider().padding(.leading, 60) // Indented divider
                }
            } else {
                Text("No replies yet.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }


            // Add new comment input area
            HStack {
                TextField("Add a reply...", text: $commentText, axis: .vertical) // Allow multiline
                    .textFieldStyle(.plain) // Use plain style for better integration
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                // Post button - enabled only when text is not empty
                Button {
                    viewModel.comment(on: post, content: commentText)
                    // Clearing commentText is now handled within the viewModel after successful post
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 5) // Add some bottom padding
        }
        .padding(.vertical, 10) // Add vertical padding to the whole section
        // Removed background and cornerRadius to let it blend with PostDetailView's ScrollView
        .dynamicTypeSize(.medium)
    }
}
