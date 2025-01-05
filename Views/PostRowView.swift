//
 //  PostRowView.swift
 //  Mustard
 //
 //  Created by VAIBHAV SRIVASTAVA on 14/09/24.
 //

import SwiftUI
import OSLog

struct PostRowView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel

    @State private var showingCommentSheet = false
    @State private var selectedImageURL: URL? = nil
    @State private var isImageFullScreen = false

    // Logger
    private let logger = OSLog(subsystem: "com.yourcompany.Mustard", category: "PostRowView")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - User Info
            HStack(alignment: .top, spacing: 12) {
                avatarView(for: post.account.avatar)

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.account.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("@\(post.account.acct)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            // MARK: - Post Content
            Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                .font(.body)
                .foregroundColor(.primary)

            // MARK: - Media Attachments
            if !post.mediaAttachments.isEmpty {
                mediaAttachmentsView()
            }

            // MARK: - Action Buttons
            actionButtons()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    // MARK: - Subviews

    /// Generates the avatar view.
    private func avatarView(for url: URL?) -> some View {
        AsyncImage(url: url) { phase in
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
    }

    /// Generates the media attachments view.
    private func mediaAttachmentsView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(post.mediaAttachments) { media in
                    mediaAttachmentView(for: media)
                }
            }
        }
    }

    /// Generates a single media attachment view.
    private func mediaAttachmentView(for media: MediaAttachment) -> some View {
        AsyncImage(url: media.url) { phase in
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
                        selectedImageURL = media.url
                        isImageFullScreen = true
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

    /// Generates the action buttons view.
    private func actionButtons() -> some View {
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
        .padding(.top, 8)
    }

    // MARK: - Action Methods

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
struct PostRowView_Previews: PreviewProvider {
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
            PostRowView(post: samplePost)
                .environmentObject(viewModel)
        }
    }
}

