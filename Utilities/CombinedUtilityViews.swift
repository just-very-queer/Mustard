//
//  CombinedUtilityViews.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import SafariServices
import CoreLocation
import Combine
import SwiftData
import SwiftSoup

// MARK: - Basic Components

struct ActionButton: View {
    @State private var showActionSheet = false
    @Binding var isExpanded: Bool
    let post: Post
    let viewModel: TimelineViewModel
    let action: () -> Void

    var body: some View {
        Button(action: { showActionSheet.toggle() }) {
            HStack {
                Image(systemName: "ellipsis")
                    .foregroundColor(.blue)
                Text("Actions")
                    .foregroundColor(.blue)
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Post Actions"),
                message: Text("Choose an action for this post"),
                buttons: [
                    .default(Text("Like")) {
                        likePost()
                    },
                    .default(Text("Repost")) {
                        repostPost()
                    },
                    .default(Text("Comment")) {
                        isExpanded.toggle()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func likePost() {
        Task {
            await viewModel.likePost(post)
        }
    }
    
    private func repostPost() {
        Task {
            await viewModel.repostPost(post)
        }
    }
}

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image.resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            case .failure:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(Color.gray.opacity(0.3)))
        .clipShape(Circle())
    }
}

struct HeaderView: View {
    let headerURL: URL?

    var body: some View {
        AsyncImage(url: headerURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            case .success(let image):
                image.resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            case .failure:
                Color.gray
                    .frame(maxWidth: .infinity, maxHeight: 200)
            @unknown default:
                EmptyView()
            }
        }
    }
}

// MARK: - Media Components

struct MediaAttachmentView: View {
    let post: Post
    var onImageTap: () -> Void
    
    var body: some View {
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
                            .cornerRadius(15)
                            .onTapGesture {
                                onImageTap()
                            }
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
            .cornerRadius(12)
        }
    }
}

struct FullScreenImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                case .success(let image):
                    image.resizable().scaledToFit().transition(.opacity)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .padding()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .padding()
            .accessibilityLabel("Close Image")
        }
    }
}

// MARK: - Web Components

struct SafariWebView: View {
    let post: Post

    var body: some View {
        if let urlString = post.url, let url = URL(string: urlString), let _ = try? SwiftSoup.parse(post.content) {
            SafariView(url: url)
        } else {
            Text("No valid URL available for this post.")
              .foregroundColor(.red)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct BrowserView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    
    var body: some View {
        SafariWebView(post: post)
    }
}

// MARK: - Utility Components

struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        Group {
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView(message)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct LinkPreview: View {
    let url: URL
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "link.circle")
                Text(url.absoluteString).lineLimit(1).truncationMode(.middle)
            }
            .foregroundColor(.blue)
        }
    }
}

// MARK: - HTML Utilities

struct HTMLUtils {
    static func convertHTMLToPlainText(html: String) -> String {
        do {
            return try SwiftSoupUtils.convertHTMLToPlainText(html: html)
        } catch {
            print("Error converting HTML to plain text: \(error)")
            return html
        }
    }
}

extension URL {
    static func detect(from content: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))?.url
    }
}

