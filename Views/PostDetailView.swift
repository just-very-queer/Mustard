//
 //  PostDetailView.swift
 //  Mustard
 //
 //  Created by VAIBHAV SRIVASTAVA on 14/09/24.
 //

import SwiftUI
import OSLog

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel

    @State private var showingCommentSheet = false

    // State for full-screen image viewing
    @State private var selectedImageURL: URL? = nil
    @State private var isImageFullScreen = false

    // Logger
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "PostDetailView")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // MARK: - User Header
                HStack(spacing: 16) {
                    avatarView(for: post.account.avatar)
                        .frame(width: 50, height: 50)
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
                Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                    .font(.body)
                    .foregroundColor(.primary)

                // MARK: - Media Attachments
                if !post.mediaAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(post.mediaAttachments) { media in
                                mediaAttachmentView(for: media)
                                    .onTapGesture {
                                        selectedImageURL = media.url
                                        isImageFullScreen = true
                                    }
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
            CommentSheetView(post: post)
                .environmentObject(viewModel)
        }
        .fullScreenCover(isPresented: $isImageFullScreen) {
            if let imageURL = selectedImageURL {
                FullScreenImageView(imageURL: imageURL, isPresented: $isImageFullScreen)
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleLike() async {
        do {
            try await viewModel.toggleLike(post: post)
            os_log("Toggled like for post ID: %{public}@", log: logger, type: .info, post.id)
        } catch {
            os_log("Failed to toggle like for post ID: %{public}@. Error: %{public}@", log: logger, type: .error, post.id, error.localizedDescription)
        }
    }

    private func toggleRepost() async {
        do {
            try await viewModel.toggleRepost(post: post)
            os_log("Toggled repost for post ID: %{public}@", log: logger, type: .info, post.id)
        } catch {
            os_log("Failed to toggle repost for post ID: %{public}@. Error: %{public}@", log: logger, type: .error, post.id, error.localizedDescription)
        }
    }

    private func avatarView(for url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 50, height: 50)
            case .success(let image):
                image
                    .resizable()
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
    }

    private func mediaAttachmentView(for media: MediaAttachment) -> some View {
        AsyncImage(url: media.url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 300, height: 300)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 300, height: 300)
                    .cornerRadius(12)
                    .clipped()
            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .frame(width: 300, height: 300)
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .accessibilityLabel("Media attachment")
    }

    // MARK: - Full-Screen Image Viewer
    struct FullScreenImageView: View {
        let imageURL: URL
        @Binding var isPresented: Bool

        var body: some View {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack {
                    Spacer()
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .edgesIgnoringSafeArea(.all)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Close Image")
                }
            }
        }
    }
}

// MARK: - Preview
struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "mockAccessToken123"
        )

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

        let mockService = MockMastodonService(shouldSucceed: true, mockPosts: [samplePost])
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.posts = [samplePost]

        return NavigationStack {
            PostDetailView(post: samplePost)
                .environmentObject(viewModel)
        }
    }
}

