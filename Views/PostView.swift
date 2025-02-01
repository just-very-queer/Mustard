//
//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI

struct PostView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    @State private var isExpanded = false
    @State private var commentText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - User Header (Twitter-like)
            HStack {
                NavigationLink(destination: ProfileView(user: User(from: post.account))) {
                    AsyncImage(url: post.account.avatar) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(post.account.display_name ?? post.account.username)
                        .font(.headline)
                    Text("@\(post.account.username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(post.createdAt, format: .dateTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)

            // MARK: - Post Content
            Text(post.content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
                .padding([.leading, .trailing])

            // MARK: - Media Attachments
            if let mediaURL = post.mediaAttachments.first?.url {
                AsyncImage(url: mediaURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // MARK: - Action Buttons
            HStack {
                Button(action: {
                    Task { await viewModel.toggleLike(on: post) }
                }) {
                    Label("\(post.favouritesCount)", systemImage: post.isFavourited ? "heart.fill" : "heart")
                        .foregroundColor(post.isFavourited ? .red : .gray)
                }

                Button(action: {
                    Task { await viewModel.toggleRepost(on: post) }
                }) {
                    Label("\(post.reblogsCount)", systemImage: post.isReblogged ? "arrow.2.squarepath.fill" : "arrow.2.squarepath")
                        .foregroundColor(post.isReblogged ? .blue : .gray)
                }

                Button(action: {
                    isExpanded.toggle()
                }) {
                    Label("\(post.repliesCount)", systemImage: "bubble.left")
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding([.leading, .bottom])

            // MARK: - Expanded Comments Section
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Replies")
                        .font(.headline)
                        .padding(.leading, 10)

                    if post.replies.isEmpty {
                        Text("No comments yet.")
                            .foregroundColor(.gray)
                            .padding(.leading, 10)
                    } else {
                        ForEach(post.replies) { reply in
                            ReplyView(reply: reply)
                        }
                    }

                    // MARK: - Comment Box
                    HStack {
                        TextField("Write a reply...", text: $commentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding([.leading, .trailing])

                        Button(action: {
                            Task {
                                await viewModel.comment(on: post, content: commentText)
                                commentText = ""
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 10)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    struct ReplyView: View {
        let reply: Post

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                AsyncImage(url: reply.account.avatar) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }

                VStack(alignment: .leading) {
                    Text(reply.account.display_name ?? reply.account.username)
                        .font(.subheadline)
                        .bold()
                    Text(reply.content)
                        .font(.body)
                }
            }
            .padding(.horizontal, 10)
        }
    }
}



