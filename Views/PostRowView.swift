//
//  PostRowView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct PostRowView: View {
    let post: Post // Changed from @ObservedObject to a simple let property
    @EnvironmentObject var viewModel: TimelineViewModel

    @State private var showingCommentSheet = false
    @State private var commentText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User Info
            HStack {
                AsyncImage(url: post.account.avatar) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }

                VStack(alignment: .leading) {
                    Text(post.account.displayName)
                        .font(.headline)
                    Text("@\(post.account.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            // Post Content
            if let attributedContent = convertHTMLToAttributedString(html: post.content) {
                Text(attributedContent)
            } else {
                Text(post.content)
                    .font(.body)
            }

            // Media Attachments
            if !post.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(post.mediaAttachments) { media in
                            AsyncImage(url: media.url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 200, height: 200)
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                        .cornerRadius(8)
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .frame(width: 200, height: 200)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 16) {
                Button(action: { toggleLike() }) {
                    Image(systemName: post.isFavourited ? "heart.fill" : "heart")
                        .foregroundColor(post.isFavourited ? .red : .gray)
                }
                Text("\(post.favouritesCount)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: { toggleRepost() }) {
                    Image(systemName: post.isReblogged ? "arrow.2.squarepath" : "arrow.2.squarepath")
                        .foregroundColor(post.isReblogged ? .green : .gray)
                }
                Text("\(post.reblogsCount)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: { showingCommentSheet = true }) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.gray)
                }
                Text("\(post.repliesCount)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
        }
        .padding()
        .sheet(isPresented: $showingCommentSheet) {
            commentSheetView
        }
    }

    // MARK: - Actions

    private func toggleLike() {
        Task {
            do {
                if post.isFavourited {
                    let updatedPost = try await MastodonService.shared.unlikePost(postID: post.id)
                    handleActionResult(.success(updatedPost))
                } else {
                    let updatedPost = try await MastodonService.shared.likePost(postID: post.id)
                    handleActionResult(.success(updatedPost))
                }
            } catch {
                handleActionResult(.failure(error))
            }
        }
    }

    private func toggleRepost() {
        Task {
            do {
                if post.isReblogged {
                    let updatedPost = try await MastodonService.shared.undoRepost(postID: post.id)
                    handleActionResult(.success(updatedPost))
                } else {
                    let updatedPost = try await MastodonService.shared.repost(postID: post.id)
                    handleActionResult(.success(updatedPost))
                }
            } catch {
                handleActionResult(.failure(error))
            }
        }
    }

    private func handleActionResult(_ result: Result<Post, Error>) {
        switch result {
        case .success(let updatedPost):
            Task { @MainActor in
                // Update the viewModel's posts array
                viewModel.updatePost(updatedPost)
            }
        case .failure(let error):
            Task { @MainActor in
                print("Action failed: \(error.localizedDescription)")
                // Update an alert in the viewModel to display the error to the user
                viewModel.alertError = MustardAppError(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Comment Sheet

    private var commentSheetView: some View {
        NavigationView {
            VStack {
                Text("Reply to \(post.account.displayName)")
                    .font(.headline)
                    .padding()

                TextEditor(text: $commentText)
                    .padding()
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .padding(.horizontal)

                Spacer()

                HStack {
                    Button("Cancel") {
                        showingCommentSheet = false
                        commentText = ""
                    }
                    Spacer()
                    Button("Post") {
                        Task {
                            do {
                                let _ = try await MastodonService.shared.comment(postID: post.id, content: commentText)
                                showingCommentSheet = false
                                commentText = ""
                            } catch {
                                print("Comment failed: \(error.localizedDescription)")
                                // Update an alert in the viewModel to display the error to the user
                                viewModel.alertError = MustardAppError(message: error.localizedDescription)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Add a Comment", displayMode: .inline)
        }
    }

    // MARK: - HTML to AttributedString Conversion

    private func convertHTMLToAttributedString(html: String) -> AttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        do {
            let nsAttrStr = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return AttributedString(nsAttrStr)
        } catch {
            print("Error converting HTML to AttributedString: \(error.localizedDescription)")
            return nil
        }
    }
}

struct PostRowView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample post for preview
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1"
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
        PostRowView(post: samplePost)
            .environmentObject(TimelineViewModel(mastodonService: MastodonService.shared))
    }
}
