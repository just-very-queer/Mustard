//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI
import LinkPresentation
import SafariServices

// MARK: - PostView (Main View)
struct PostView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    
    @State private var isExpanded = false
    @State private var commentText = ""
    @State private var showFullText = false
    @State private var showImageViewer = false
    @State private var showBrowserView = false
    @State private var showCommentSection = false
    @State private var isLoading = false  // Loading indicator for network requests
    @State private var networkError: String? = nil  // Store network error messages
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            UserHeaderView(post: post)
            
            // Display error message if any
            if let networkError = networkError {
                Text("Error: \(networkError)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Post content and media
            if showBrowserView {
                SafariWebView(post: post)  // Reuse SafariWebView here
            } else if showImageViewer {
                FullScreenImageView(imageURL: post.mediaAttachments.first?.url ?? URL(string: "https://example.com")!, isPresented: $showImageViewer)
            } else {
                PostContentView(post: post, showFullText: $showFullText)
            }
            
            // Media attachments
            MediaAttachmentView(post: post, onImageTap: {
                self.showImageViewer.toggle()
            })
            
            // Like, Repost, and Comment buttons below the post
            HStack(spacing: 20) {
                PostActionButton(icon: "heart.fill", label: "Like") {
                    Task {
                        isLoading = true
                        await viewModel.likePost(post)
                        isLoading = false
                    }
                }
                
                PostActionButton(icon: "arrow.2.squarepath", label: "Repost") {
                    Task {
                        isLoading = true
                        await viewModel.repostPost(post)
                        isLoading = false
                    }
                }
                
                PostActionButton(icon: "bubble.left.fill", label: "Comment") {
                    showCommentSection.toggle()
                }
            }
            .padding(.top, 5)
            
            // Expandable comment section
            if showCommentSection {
                ExpandedCommentsSection(post: post, isExpanded: $isExpanded, commentText: $commentText, viewModel: viewModel)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 8)
        .shadow(color: .primary.opacity(0.05), radius: 8, x: 0, y: 3)
        .dynamicTypeSize(.medium)
        .onTapGesture {
            showBrowserView.toggle()
        }
    }
}

// MARK: - ExpandedCommentsSection (Comment Section)
struct ExpandedCommentsSection: View {
    let post: Post
    @Binding var isExpanded: Bool
    @Binding var commentText: String
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comments")
                .font(.headline)
                .padding(.horizontal)
                .foregroundColor(.primary)


            ForEach(post.replies ?? [], id: \.id) { comment in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) { // Using HStack for avatar and user info, like in Version 1, but cleaner
                        AvatarView(url: comment.account?.avatar, size: 30)
                        VStack(alignment: .leading) {
                            Text(comment.account?.display_name ?? "")
                                .font(.subheadline)
                            Text("@\(comment.account?.acct ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal) // Padding for user info
                    Text(comment.content)
                        .font(.body)
                        .padding(.horizontal)
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 5)
            }


            // Add new comment input
            HStack {
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .foregroundColor(.primary)


                Button(action: {
                    Task {
                        await viewModel.comment(on: post, content: commentText)
                        commentText = "" // Clear after posting
                    }
                }) {
                    Text("Post")
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding(.vertical, 5)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .dynamicTypeSize(.medium)
    }
}

// MARK: - PostContentView (Post Text)
struct PostContentView: View {
    let post: Post
    @Binding var showFullText: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let safeContent = post.content.safeHTMLToAttributedString {
                AttributedTextView(attributedText: safeContent)
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary) // Ensure text visibility in both modes
                    .padding(.horizontal)
            }
            
            // Show "Show More" button if post content exceeds a certain limit
            if !showFullText && post.content.components(separatedBy: .newlines).count > 3 {
                ShowMoreButton(showFullText: $showFullText)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - ShowMoreButton (Show More / Show Less button)
struct ShowMoreButton: View {
    @Binding var showFullText: Bool
    
    var body: some View {
        Button(action: { showFullText.toggle() }) {
            Text(showFullText ? "Show Less" : "Show More")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }
}

// MARK: - UserHeaderView (User Header in Post and Comment)
struct UserHeaderView: View {
    let post: Post
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    
    @State private var isNavigatingToProfile = false
    @State private var selectedAccount: Account? = nil
    
    var body: some View {
        HStack {
            AvatarView(url: post.account?.avatar, size: post.account?.avatar != nil ? 50 : 40)
                .onTapGesture {
                    if let account = post.account {
                        selectedAccount = account
                        isNavigatingToProfile = true
                    }
                }
            
            VStack(alignment: .leading) {
                Text(post.account?.display_name ?? post.account?.username ?? "")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("@\(post.account?.username ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $isNavigatingToProfile) {
            if let user = selectedAccount?.toUser() {
                ProfileView(user: user)
                    .environmentObject(profileViewModel)
                    .environmentObject(authViewModel)
                    .environmentObject(timelineViewModel)
            }
        }
    }
}

// MARK: - PostActionButton (Reusable Post Action Button)
struct PostActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(label)
            }
        }
    }
}

// MARK: - AttributedTextView (For rendering HTML safely)
struct AttributedTextView: UIViewRepresentable {
    var attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = attributedText
    }
}

// MARK: - String Extension (To convert HTML to NSAttributedString)
extension String {
    var safeHTMLToAttributedString: NSAttributedString? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        do {
            return try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
        } catch {
            return nil
        }
    }
}
