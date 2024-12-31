//
//  CommentSheetView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

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
            } catch {
                isSubmitting = false
                errorMessage = "Failed to post comment: \(error.localizedDescription)"
            }
        }
    }
}

