//
//  PostDetailView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel

    @State private var showingCommentSheet = false

    // State for full-screen image viewing
    @State private var selectedImageURL: URL? = nil
    @State private var isImageFullScreen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // MARK: - User Header
                HStack(spacing: 16) {
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

                    VStack(alignment: .leading) {
                        Text(post.account.displayName)
                            .font(.headline)
                        Text("@\(post.account.acct)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top)

                // MARK: - Post Content
                let attributedContent = HTMLUtils.convertHTMLToAttributedString(html: post.content)
                Text(attributedContent)
                    .font(.body)
                    .foregroundColor(.primary)

                // MARK: - Media Attachments
                if !post.mediaAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(post.mediaAttachments) { media in
                                AsyncImage(url: media.url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 250, height: 250)
                                    case .success(let image):
                                        image.resizable()
                                            .scaledToFill()
                                            .frame(width: 250, height: 250)
                                            .cornerRadius(12)
                                            .clipped()
                                            .onTapGesture {
                                                selectedImageURL = media.url
                                                isImageFullScreen = true
                                            }
                                    case .failure:
                                        Image(systemName: "photo")
                                            .resizable()
                                            .frame(width: 250, height: 250)
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
                            await toggleLike()
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
                            await toggleRepost()
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
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Post Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCommentSheet) {
            // Present the external CommentSheetView which handles its own state and errors
            CommentSheetView(post: post)
                .environmentObject(viewModel)
        }
        // Full-screen image viewer
        .fullScreenCover(isPresented: $isImageFullScreen) {
            if let imageURL = selectedImageURL {
                FullScreenImageView(imageURL: imageURL, isPresented: $isImageFullScreen)
            }
        }
    }

    // MARK: - Action Methods

    private func toggleLike() async {
        await viewModel.toggleLike(post: post)
    }

    private func toggleRepost() async {
        await viewModel.toggleRepost(post: post)
    }

    // MARK: - Full-Screen Image Viewer
    struct FullScreenImageView: View {
        let imageURL: URL
        @Binding var isPresented: Bool

        var body: some View {
            ZStack(alignment: .topTrailing) {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .edgesIgnoringSafeArea(.all)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }

                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
                .accessibilityLabel("Close Image")
            }
        }
    }
}

struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample account
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "mockAccessToken123"
        )
        
        // Create a sample post
        let samplePost = Post(
            id: "1",
            content: "<p>Hello, world!</p>",
            createdAt: Date(),
            account: sampleAccount,
            mediaAttachments: [],
            isFavourited: false,
            isReblogged: false,
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0
        )
        
        // Initialize the MockMastodonService (updated to match its actual initializer)
        let mockService = MockMastodonService(shouldSucceed: true) // Adjust as necessary

        // Add the sample post to the service's mockPosts if applicable
        mockService.mockPosts = [samplePost]

        // Initialize the TimelineViewModel with the mock service
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.posts = [samplePost]
        
        return NavigationStack {
            PostDetailView(post: samplePost)
                .environmentObject(viewModel)
        }
    }
}



