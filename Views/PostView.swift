//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import SafariServices
#endif
import SwiftSoup

// MARK: - PostView (Main View)
struct PostView: View {
    let post: Post          // Outer post, might be a reblog
    @ObservedObject var viewModel: TimelineViewModel
    var viewProfileAction: (User) -> Void

    @State private var showImageViewer = false
    @State private var showBrowserView = false

    let interestScore: Double

    // Show original post if reblog, else self
    private var displayPost: Post {
        post.reblog ?? post
    }

    // Account who reblogged (if any)
    private var rebloggerAccount: Account? {
        post.reblog != nil ? post.account : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            UserHeaderView(
                post: displayPost,
                rebloggerAccount: rebloggerAccount,
                viewProfileAction: viewProfileAction
            )

            PostContentView(
                post: displayPost,
                currentUserAccountID: viewModel.currentUserAccountID
            )

            MediaAttachmentView(
                post: displayPost,
                onImageTap: { self.showImageViewer.toggle() }
            )

            PostActionsViewRevised(
                post: displayPost,
                viewModel: viewModel
            )
            .padding(.top, 5)

            if viewModel.isLoading(forPostId: displayPost.id) {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 8)
        .shadow(color: .primary.opacity(0.05), radius: 8, x: 0, y: 3)
        .dynamicTypeSize(.medium)
        .sheet(isPresented: $showImageViewer) {
            if let imageURL = displayPost.mediaAttachments?.first?.url {
                FullScreenImageView(imageURL: imageURL, isPresented: $showImageViewer)
            }
        }
        .sheet(isPresented: $showBrowserView) {
            if let urlString = displayPost.url, let url = URL(string: urlString) {
    #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                SafariView(url: url)
    #else
                Text("Web browser preview not available on this platform. URL: \(url.absoluteString)")
                    .padding()
    #endif
            }
        }
        .interestHighlight(isActive: interestScore > 5.0, score: interestScore)
    }
}

// MARK: - Revised PostActionsView
struct PostActionsViewRevised: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        HStack {
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

            Button {
                viewModel.toggleRepost(for: post)
            } label: {
                Image(systemName: "arrow.2.squarepath")
                    .foregroundColor(post.isReblogged ? .green : .gray)
                Text("\(post.reblogsCount)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

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

            Button {
                viewModel.logNotInterested(for: post)
            } label: {
                Image(systemName: "hand.thumbsdown")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

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

// MARK: - PostContentView

struct PostContentView: View {
    let post: Post
    let currentUserAccountID: String?

    // For dynamically sizing the AttributedTextView
    @State private var desiredTextHeight: CGFloat = 0
    // State to hold the computed NSAttributedString
    @State private var attributedContent: NSAttributedString = NSAttributedString()

    @State private var detectedLinkCard: Card? = nil
    @State private var isLoadingLinkPreview: Bool = false

    // Environment to detect color scheme for theming
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // If the post has HTML content, render it via AttributedTextView
            if !post.content.isEmpty {
                GeometryReader { geometry in
                    AttributedTextView(
                        attributedString: attributedContent, // Use the state variable
                        maxLayoutWidth: geometry.size.width,
                        onLinkTap: { url in
                            // Log the tap interaction
                            RecommendationService.shared.logInteraction(
                                statusID: post.id,
                                actionType: .linkOpen,
                                accountID: currentUserAccountID,
                                linkURL: url.absoluteString
                            )

                            // If it's a web URL, open in browser
    #if canImport(UIKit) && !os(watchOS)
                            if url.scheme?.starts(with: "http") == true || url.scheme?.starts(with: "https") == true {
                                UIApplication.shared.open(url)
                            }
    #endif
                            // You can add more logic for mention URLs (e.g., navigate to profile)
                        },
                        desiredHeight: $desiredTextHeight
                    )
                    .frame(minHeight: desiredTextHeight)
                }
                .frame(minHeight: desiredTextHeight)
                .padding(.horizontal)
            }

            // Link preview (if any)
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
            // Perform NSAttributedString creation off the main thread.
            let newAttributedContent = HTMLUtils.nsAttributedStringFromHTML(htmlString: post.content)

            // Check for cancellation before updating the UI.
            if Task.isCancelled { return }

            // Switch to the main actor to update the @State variable.
            await MainActor.run {
                self.attributedContent = newAttributedContent
            }

            // Log "view" interaction
            RecommendationService.shared.logInteraction(
                statusID: post.id,
                actionType: .view,
                accountID: currentUserAccountID,
                authorAccountID: post.account?.id,
                postURL: post.url,
                tags: post.tags?.compactMap { $0.name }
            )

            // Fetch or use existing link preview
            self.detectedLinkCard = nil
            self.isLoadingLinkPreview = false

            if let existingCard = post.card {
                self.detectedLinkCard = existingCard
            } else {
                let textToDetect = post.content
                if !textToDetect.isEmpty, let firstURL = detectFirstURL(in: textToDetect) {
                    self.isLoadingLinkPreview = true
                    let fetchedCard = await HTMLUtils.fetchLinkMetadata(from: firstURL)
                    if Task.isCancelled { return }
                    self.detectedLinkCard = fetchedCard
                    self.isLoadingLinkPreview = false
                }
            }
        }
    }

    /// Detects the first URL in a given string
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

// MARK: - ShowMoreButton (No longer used, but kept for reference)
/*
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
*/

struct UserHeaderView: View {
    let post: Post
    let rebloggerAccount: Account?
    var viewProfileAction: (User) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reblogger = rebloggerAccount {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.caption)
                        .foregroundColor(.gray)
                    AvatarView(url: reblogger.avatar, size: 20)
                    Text(reblogger.display_name ?? reblogger.username)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Text("reblogged")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.leading)
                .padding(.bottom, 2)
            }

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
        }
        .padding(.top, 5)
    }
}
