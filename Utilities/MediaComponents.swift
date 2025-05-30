//
//  MediaComponents.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

// MARK: - Media Components

struct MediaAttachmentView: View {
    let post: Post
    var onImageTap: () -> Void

    var body: some View {
        // Safely unwrap post.mediaAttachments and then get the first element
        if let attachments = post.mediaAttachments, let media = attachments.first, let mediaURL = media.url {
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
            .cornerRadius(12) // This cornerRadius might be better applied to the AsyncImage's content directly if needed
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
