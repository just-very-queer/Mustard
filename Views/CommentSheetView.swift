//
//  CommentSheetView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

/// View for adding a comment to a post.
struct CommentSheetView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var commentText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
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

                if isSubmitting {
                    ProgressView("Posting Comment...")
                        .padding()
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()

                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                        commentText = ""
                    }
                    Spacer()
                    Button("Post") {
                        submitComment()
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
                .padding()
            }
            .navigationBarTitle("Add a Comment", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                        commentText = ""
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        submitComment()
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submitComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Comment cannot be empty."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.comment(post: post, content: commentText)
                isSubmitting = false
                presentationMode.wrappedValue.dismiss()
                commentText = ""
            } catch {
                isSubmitting = false
                errorMessage = "Failed to post comment: \(error.localizedDescription)"
            }
        }
    }
}

struct CommentSheetView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample Data for Preview
        class PreviewTimelineViewModel: TimelineViewModel {
            let sampleAccount: Account
            let samplePost: Post

            override init(mastodonService: MastodonServiceProtocol) {
                let mockService = MockMastodonService()
                self.sampleAccount = Account(
                    id: "a1",
                    username: "user1",
                    displayName: "User One",
                    avatar: URL(string: "https://example.com/avatar1.png")!,
                    acct: "user1",
                    instanceURL: URL(string: "https://mastodon.social")!,
                    accessToken: "testToken"
                )
                self.samplePost = Post(
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
                super.init(mastodonService: mockService)
                self.posts = [samplePost]
            }

            override func comment(post: Post, content: String) async throws {
                // Mock comment action
                // For example, simulate a delay
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                // Optionally, modify the post's repliesCount if needed
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].repliesCount += 1
                }
            }
        }

        let viewModel = PreviewTimelineViewModel(mastodonService: MockMastodonService())

        return CommentSheetView(post: viewModel.samplePost)
            .environmentObject(viewModel)
    }
}

