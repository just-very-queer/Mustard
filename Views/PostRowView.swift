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
                Button(action: {
                    Task {
                        await viewModel.toggleLike(post: post)
                    }
                }) {
                    Image(systemName: post.isFavourited ? "heart.fill" : "heart")
                        .foregroundColor(post.isFavourited ? .red : .gray)
                }
                Text("\(post.favouritesCount)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: {
                    Task {
                        await viewModel.toggleRepost(post: post)
                    }
                }) {
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
                            await viewModel.comment(post: post, content: commentText)
                            showingCommentSheet = false
                            commentText = ""
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

