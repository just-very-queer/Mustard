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

    // Assuming TimelineViewModel exposes currentUserAccountID or a similar property
    // For now, let's assume viewModel.currentUserAccountID is available.
    // If not, this would need to be plumbed through.
    let interestScore: Double // Added for interest highlighting

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // User Header - Pass profile navigation action
            UserHeaderView(post: post, viewProfileAction: viewProfileAction)

            // Content
            PostContentView(post: post, showFullText: $showFullText, currentUserAccountID: viewModel.currentUserAccountID) // Pass it here

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
        .interestHighlight(isActive: interestScore > 5.0, score: interestScore) // Threshold = 5.0
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
    let currentUserAccountID: String? // Added to receive current user ID

    // State to hold the computed attributed string
    @State private var displayedAttributedString: AttributedString? = nil
    @State private var plainTextContentForShowMore: String = "" // For "Show More" logic
    @State private var detectedLinkCard: Card? = nil
    @State private var isLoadingLinkPreview: Bool = false

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
                Text(HTMLUtils.convertHTMLToPlainText(html: post.content)) // Use plain text as fallback
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
            }

            // "Show More" button
            if !showFullText && plainTextContentForShowMore.count > 200 { // Use state variable
                 ShowMoreButton(showFullText: $showFullText)
            }

            // Link Preview Section
            if isLoadingLinkPreview {
                ProgressView()
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let card = detectedLinkCard {
                LinkPreview(card: card, postID: post.id, currentUserAccountID: currentUserAccountID) // Pass postID and currentUserAccountID
                    .padding(.horizontal) // Add padding around the LinkPreview
                    .padding(.top, 5) // Add some space above the LinkPreview
            }
        }
        .padding(.vertical, 5)
        .task(id: post.id) { // Re-run when post.id changes (safer than post.content for triggering)
            // 1. AttributedString and PlainText conversion (for Show More)
            self.displayedAttributedString = HTMLUtils.attributedStringFromHTML(htmlString: post.content)
            self.plainTextContentForShowMore = HTMLUtils.convertHTMLToPlainText(html: post.content) // Calculate once

            // 2. Link Preview Logic
            self.detectedLinkCard = nil // Reset
            self.isLoadingLinkPreview = false // Reset

            // Log .view interaction
            RecommendationService.shared.logInteraction(
                statusID: post.id,
                actionType: .view,
                accountID: currentUserAccountID, // Passed in
                authorAccountID: post.account?.id,
                postURL: post.url,
                tags: post.tags?.compactMap { $0.name } // Assuming Tag has 'name'
            )

            if let existingCard = post.card {
                self.detectedLinkCard = existingCard
            } else {
                // Extract URL from post content (HTML string)
                // NSDataDetector works better on plain text, but let's try with raw HTML first.
                // For better results, consider extracting URLs from the plain text version.
                let textToDetect = post.content // Or plainText for potentially cleaner URL detection
                if let firstURL = detectFirstURL(in: textToDetect) {
                    self.isLoadingLinkPreview = true
                    // Asynchronously fetch metadata
                    let fetchedCard = await HTMLUtils.fetchLinkMetadata(from: firstURL)
                    // Ensure the task has not been cancelled or post.id changed again
                    if Task.isCancelled { return }
                    // Check if the current post context is still the same
                    // This check might be overly cautious if id in .task(id: post.id) handles it well
                    // but good for robustness if updates are frequent.
                    // For simplicity here, we assume post.id check in .task is sufficient.
                    
                    self.detectedLinkCard = fetchedCard
                    self.isLoadingLinkPreview = false
                }
            }
        }
    }

    private func detectFirstURL(in text: String) -> URL? {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            return matches.first?.url
        } catch {
            print("Error creating URL detector: \(error)")
            return nil
        }
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
                LazyVStack(spacing: 0) { // Added LazyVStack for replies
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
                            PostContentView(post: reply, showFullText: .constant(true), currentUserAccountID: String?) // Always show full text for replies

                    }
                    .padding(.bottom, 5)
                    Divider().padding(.leading, 60) // Indented divider
                    }
                } // End of ForEach
            } else { // End of LazyVStack
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
