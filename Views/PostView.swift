//  PostView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 31/01/25.
//

import SwiftUI
import LinkPresentation

struct PostView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    @State private var isExpanded = false
    @State private var commentText = ""
    @State private var showFullText = false
    @State private var linkPreview: LPLinkMetadata?
    @State private var isLoadingLinkPreview = false

    private var contentLines: Int {
        post.content.components(separatedBy: .newlines).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - User Header
            HStack(alignment: .top) {
                NavigationLink(destination: ProfileView(user: post.account?.toUser() ?? User(id: "invalid", username: "unknown", acct: "unknown", display_name: "Unknown User", locked: false, bot: false, discoverable: false, indexable: false, group: false, created_at: Date(), note: "", url: "", avatar: "", avatar_static: "", header: "", header_static: "", followers_count: 0, following_count: 0, statuses_count: 0, last_status_at: "", suspended: false, hide_collections: false, noindex: false, source: nil, emojis: [], roles: [], fields: []))) {
                    AvatarView(url: post.account?.avatar, size: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.account?.display_name ?? post.account!.username)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("@\(post.account?.username ?? "unknown_user")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // MARK: - Post Content
            VStack(alignment: .leading) {
                Text(post.content.safeHTMLToAttributedString)
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onAppear {
                                let font = UIFont.preferredFont(forTextStyle: .body)
                                let constraintWidth = proxy.size.width

                                if let nsAttributedString = try? NSAttributedString(data: post.content.data(using: .utf8)!,
                                   options: [.documentType: NSAttributedString.DocumentType.html,
                                             .characterEncoding: String.Encoding.utf8.rawValue],
                                   documentAttributes: nil) {
                                    let boundingRect = nsAttributedString.boundingRect(with: CGSize(width: constraintWidth, height: .greatestFiniteMagnitude),
                                                                                      options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                                      context: nil)
                                    let calculatedLines = Int(ceil(boundingRect.height / font.lineHeight))
                                    showFullText = calculatedLines <= 3
                                } else {
                                    showFullText = true
                                }
                            }
                        }
                    )

                if !showFullText && contentLines > 3 {
                    Button("Show More") {
                        withAnimation {
                            showFullText = true
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal)
                }
            }

            // MARK: - Media Attachments
            if let media = post.mediaAttachments.first, let mediaURL = media.url {
                AsyncImage(url: mediaURL) { phase in
                    Group {
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        case .success(let image):
                            image.resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .cornerRadius(10)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal)
            }

            // MARK: - Action Buttons
            HStack(spacing: 20) {
                ActionButton(
                    image: post.isFavourited ? "heart.fill" : "heart",
                    text: post.favouritesCount.formatted(),
                    color: post.isFavourited ? .red : .secondary
                ) {
                    Task { await viewModel.toggleLike(on: post) }
                }

                ActionButton(
                    image: post.isReblogged ? "arrow.2.squarepath.fill" : "arrow.2.squarepath",
                    text: post.reblogsCount.formatted(),
                    color: post.isReblogged ? .green : .secondary
                ) {
                    Task { await viewModel.toggleRepost(on: post) }
                }

                ActionButton(
                    image: "bubble.left",
                    text: post.repliesCount.formatted(),
                    color: .secondary
                ) {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }

                Spacer()
            }
            .padding(.horizontal)

            // MARK: - Expanded Comments Section
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Replies")
                        .font(.headline)
                        .padding(.horizontal)

                    if post.replies?.isEmpty ?? true {
                        Text("No replies yet")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        if let replies = post.replies {
                            ForEach(replies) { reply in
                                ReplyView(reply: reply)
                            }
                        }
                    }

                    HStack {
                        TextField("Write a reply...", text: $commentText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            Task {
                                await viewModel.comment(on: post, content: commentText)
                                commentText = ""
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(commentText.isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal, 8)
        .shadow(color: .primary.opacity(0.05), radius: 5, x: 0, y: 2)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - Supporting Views

private struct ReplyView: View {
    let reply: Post

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: reply.account?.avatar, size: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(reply.account?.display_name ?? "Display Name")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)

                Text(reply.content.safeHTMLToAttributedString)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            Spacer()

            Text(reply.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

private extension String {
    var safeHTMLToAttributedString: AttributedString {
        do {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
                .defaultAttributes: [
                    NSAttributedString.Key.foregroundColor: UIColor.label,
                    NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)
                ]
            ]

            return try AttributedString(
                NSAttributedString(
                    data: Data(utf8),
                    options: options,
                    documentAttributes: nil
                )
            )
        } catch {
            return AttributedString(self)
        }
    }
}

extension Account {
    func toUser() -> User {
        return User(from: self)
    }
}
