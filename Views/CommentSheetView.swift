//
//  CommentSheetView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import OSLog

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
                // Header indicating to whom you're replying
                Text("Replying to \(post.account.displayName)")
                    .font(.headline)
                    .padding(.top, 20)

                // Comment Text Editor
                TextEditor(text: $commentText)
                    .padding()
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .navigationTitle("Add a Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .accessibilityLabel("Cancel Comment")
                }
                // Post Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        submitComment()
                    }
                    .disabled(
                        commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        isSubmitting
                    )
                    .accessibilityLabel("Post Comment")
                }
            }
            .overlay(
                Group {
                    if isSubmitting {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        ProgressView("Posting Comment...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            )
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    /// Handles the comment submission process.
    private func submitComment() {
        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            errorMessage = "Comment cannot be empty."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.comment(post: post, content: trimmedComment)
                isSubmitting = false
                presentationMode.wrappedValue.dismiss()
                os_log("Successfully posted comment for post ID: %{public}@", log: OSLog.default, type: .info, post.id)
            } catch {
                isSubmitting = false
                self.errorMessage = "Failed to post comment: \(error.localizedDescription)"
                os_log("Failed to post comment for post ID: %{public}@. Error: %{public}@", log: OSLog.default, type: .error, post.id, error.localizedDescription)
            }
        }
    }
}

struct CommentSheetView_Previews: PreviewProvider {
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
            CommentSheetView(post: samplePost)
                .environmentObject(viewModel)
        }
    }
}
