//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import OSLog
import SwiftData

struct PostView: View {
    let post: Post
    @EnvironmentObject var viewModel: TimelineViewModel
    @State private var isExpanded = false
    @State private var isShowingSheet = false
    @State private var sheetType: SheetType = .comment
    @State private var webViewURL: URL?

    enum SheetType {
        case comment, webView
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            contentBody
            if isExpanded {
                mediaView
                actionButtons
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
        .onTapGesture { isExpanded.toggle() }
        .sheet(isPresented: $isShowingSheet) {
            switch sheetType {
            case .comment:
                CommentSheet(post: post, onDismiss: { isShowingSheet = false })
                    .environmentObject(viewModel)
            case .webView:
                if let url = webViewURL { SafariWebView(url: url) }
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: 12) {
            avatarView(for: post.account.avatar)
            VStack(alignment: .leading, spacing: 4) {
                Text(post.account.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("@\(post.account.acct)")
                    .font(.caption)
                    .foregroundColor(.gray)
                if isExpanded {
                    Text(post.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
    }

    // MARK: - Content Body
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 3)
                .frame(maxWidth: 250, alignment: .leading)

            if let url = detectURL(from: post.content) {
                LinkPreview(url: url) {
                    webViewURL = url
                    sheetType = .webView
                    isShowingSheet = true
                }
            }
        }
    }

    // MARK: - Media View
    private var mediaView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(post.mediaAttachments) { media in
                    AsyncImage(url: media.url) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .cornerRadius(12)
                        case .failure: Image(systemName: "photo")
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(width: 200, height: 200)
                }
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 24) {
            actionButton(image: post.isFavourited ? "heart.fill" : "heart", text: "\(post.favouritesCount)", color: post.isFavourited ? .red : .gray) {
                Task { await viewModel.toggleLike(on: post) }
            }
            actionButton(image: "arrow.2.squarepath", text: "\(post.reblogsCount)", color: post.isReblogged ? .green : .gray) {
                Task { await viewModel.toggleRepost(on: post) }
            }
            actionButton(image: "bubble.right", text: "\(post.repliesCount)", color: .blue) {
                sheetType = .comment
                isShowingSheet = true
            }
        }
    }

    // MARK: - Helper Views
    private func actionButton(image: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: image)
                    .foregroundColor(color)
                Text(text)
                    .foregroundColor(.primary)
            }
        }
    }

    private func avatarView(for url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            case .failure:
                Image(systemName: "person.crop.circle")
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 40, height: 40)
    }

    private func detectURL(from content: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))?.url
    }
}

struct CommentSheet: View {
    let post: Post
    let onDismiss: () -> Void
    @EnvironmentObject var viewModel: TimelineViewModel
    @State private var commentText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Replying to \(post.account.displayName)")
                    .font(.headline)
                    .padding(.top)
                TextEditor(text: $commentText)
                    .padding()
                    .frame(minHeight: 150)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal)
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Add a Comment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") { submitComment() }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .overlay(loadingOverlay)
            .alert(isPresented: .constant(errorMessage != nil)) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("OK")))
            }
        }
    }

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
                try await viewModel.comment(on: post, content: trimmedComment)
                onDismiss()
            } catch {
                errorMessage = "Failed to post comment: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    private var loadingOverlay: some View {
        Group {
            if isSubmitting {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                ProgressView("Posting Comment...")
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
}
