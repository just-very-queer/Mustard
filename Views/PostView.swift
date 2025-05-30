//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI
// import LinkPresentation // REMOVED: Not directly used in this file's current structure
// Conditionally import SafariServices for UIKit-based platforms
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import SafariServices
#endif
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

    let interestScore: Double // Added for interest highlighting

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // User Header - Pass profile navigation action
            UserHeaderView(post: post, viewProfileAction: viewProfileAction)

            // Content
            PostContentView(post: post, showFullText: $showFullText, currentUserAccountID: viewModel.currentUserAccountID)

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
            if let imageURL = post.mediaAttachments.first?.url {
                FullScreenImageView(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
        // Sheet for WebView (Uses local state and post data)
        .sheet(isPresented: $showBrowserView) {
            if let urlString = post.url, let url = URL(string: urlString) {
                #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                SafariView(url: url) // Assumes SafariView is defined conditionally elsewhere
                #else
                // Fallback for platforms where SafariView (SFSafariViewController) is not available
                // On macOS, you might use Link to open in default browser, or a WKWebView wrapper
                Text("Web browser preview not available on this platform. URL: \(url.absoluteString)")
                    .padding()
                // Or, to open in the default browser on macOS:
                // Link("Open URL", destination: url).padding()
                #endif
            }
        }
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
                Text("\(post.favouritesCount)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Repost Button
            Button {
                viewModel.toggleRepost(for: post)
            } label: {
                Image(systemName: post.isReblogged ? "arrow.2.squarepath" : "arrow.2.squarepath")
                    .foregroundColor(post.isReblogged ? .green : .gray)
                 Text("\(post.reblogsCount)")
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
                Text("\(post.repliesCount)")
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
                 Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Subviews

struct PostContentView: View {
    let post: Post
    @Binding var showFullText: Bool
    let currentUserAccountID: String?

    @State private var displayedAttributedString: AttributedString? = nil
    @State private var plainTextContentForShowMore: String = ""
    @State private var detectedLinkCard: Card? = nil
    @State private var isLoadingLinkPreview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let attrString = displayedAttributedString {
                Text(attrString)
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
            } else {
                Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
            }

            if !showFullText && plainTextContentForShowMore.count > 200 {
                 ShowMoreButton(showFullText: $showFullText)
            }

            if isLoadingLinkPreview {
                ProgressView()
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let card = detectedLinkCard {
                LinkPreview(card: card, postID: post.id, currentUserAccountID: currentUserAccountID)
                    .padding(.horizontal)
                    .padding(.top, 5)
            }
        }
        .padding(.vertical, 5)
        .task(id: post.id) {
            self.displayedAttributedString = HTMLUtils.attributedStringFromHTML(htmlString: post.content)
            self.plainTextContentForShowMore = HTMLUtils.convertHTMLToPlainText(html: post.content)

            self.detectedLinkCard = nil
            self.isLoadingLinkPreview = false

            RecommendationService.shared.logInteraction(
                statusID: post.id,
                actionType: .view,
                accountID: currentUserAccountID,
                authorAccountID: post.account?.id,
                postURL: post.url,
                tags: post.tags?.compactMap { $0.name }
            )

            if let existingCard = post.card {
                self.detectedLinkCard = existingCard
            } else {
                let textToDetect = post.content
                if let firstURL = detectFirstURL(in: textToDetect) {
                    self.isLoadingLinkPreview = true
                    let fetchedCard = await HTMLUtils.fetchLinkMetadata(from: firstURL)
                    if Task.isCancelled { return }
                    
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

struct ExpandedCommentsSection: View {
    let post: Post
    @Binding var isExpanded: Bool
    @Binding var commentText: String
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.horizontal)

            Text("Replies")
                .font(.headline)
                .padding(.horizontal)
                .foregroundColor(.primary)

            if let replies = post.replies, !replies.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(replies) { reply in
                        VStack(alignment: .leading, spacing: 5) {
                            UserHeaderView(post: reply, viewProfileAction: { user in
                                viewModel.navigateToProfile(user)
                        })
                            PostContentView(post: reply, showFullText: .constant(true), currentUserAccountID: viewModel.currentUserAccountID)
                    }
                    .padding(.bottom, 5)
                    Divider().padding(.leading, 60)
                    }
                }
            } else {
                Text("No replies yet.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }

            HStack {
                TextField("Add a reply...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button {
                    viewModel.comment(on: post, content: commentText)
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
