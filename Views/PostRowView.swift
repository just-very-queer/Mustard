//
//  PostRowView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct PostRowView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel

    @State private var showingCommentSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - User Info
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: post.account.avatar) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .accessibilityLabel("\(post.account.displayName)'s avatar")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.account.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("@\(post.account.acct)") // Corrected from post.acct
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            // MARK: - Post Content
            Text(HTMLUtils.convertHTMLToAttributedString(html: post.content))
                .font(.body)
                .foregroundColor(.primary)

            // MARK: - Media Attachments
            if !post.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(post.mediaAttachments) { media in
                            AsyncImage(url: media.previewUrl ?? media.url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 200, height: 200)
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 200)
                                        .cornerRadius(12)
                                        .clipped()
                                        .onTapGesture {
                                            // Implement full-screen image viewing if desired
                                        }
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .frame(width: 200, height: 200)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .accessibilityLabel("Media attachment")
                        }
                    }
                }
            }

            // MARK: - Action Buttons
            HStack(spacing: 24) {
                // Like Button
                Button(action: {
                    Task {
                        await viewModel.toggleLike(post: post)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isFavourited ? "heart.fill" : "heart")
                            .foregroundColor(post.isFavourited ? .red : .gray)
                        Text("\(post.favouritesCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .accessibilityLabel(post.isFavourited ? "Unlike" : "Like")

                // Repost Button
                Button(action: {
                    Task {
                        await viewModel.toggleRepost(post: post)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(post.isReblogged ? .green : .gray)
                        Text("\(post.reblogsCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .accessibilityLabel(post.isReblogged ? "Undo Repost" : "Repost")

                // Comment Button
                Button(action: {
                    showingCommentSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(post.repliesCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .accessibilityLabel("Comment")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingCommentSheet) {
            CommentSheetView(post: post)
                .environmentObject(viewModel)
        }
    }

    struct PostRowView_Previews: PreviewProvider {
        static var previews: some View {
            // Initialize PreviewService with default mock posts
            let previewService = PreviewService()
            let timelineViewModel = TimelineViewModel(mastodonService: previewService)
            // Replace 'mockPosts' with 'posts'
            timelineViewModel.posts = previewService.mockPosts

            // Select a specific post for preview
            guard let samplePost = previewService.mockPosts.first else {
                fatalError("No mock posts available for preview.")
            }

            return NavigationStack {
                PostRowView(post: samplePost)
                    .environmentObject(timelineViewModel)
            }
        }
    }

}

