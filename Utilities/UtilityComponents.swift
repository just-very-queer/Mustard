//
//  UtilityComponents.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

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

// SafariServices import removed as SFSafariViewController is no longer used in this file.

struct LinkPreview: View {
    let card: Card
    let postID: String? // Added to associate link click with a post
    let currentUserAccountID: String? // Added for logging

    var body: some View {
        VStack(alignment: .leading) {
            if let imageURLString = card.image, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 150) // Placeholder height
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200) // Max height for the image
                            .clipped()
                    case .failure:
                        Image(systemName: "photo") // Placeholder for failure
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.headline)
                    .lineLimit(2)

                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                HStack {
                    if let providerName = card.providerName, !providerName.isEmpty {
                        Text(providerName)
                            .font(.footnote)
                            .foregroundColor(.blue)
                    } else if let domain = URL(string: card.url)?.host {
                        Text(domain)
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    Spacer() // Pushes content to the left
                }
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(UIColor.systemGray6)) // Light gray background
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .onTapGesture {
            if let urlToOpen = URL(string: card.embedUrl ?? card.url) {
                print("Attempting to open URL: \(urlToOpen)")

                // Log .linkOpen interaction
                RecommendationService.shared.logInteraction(
                    statusID: postID, // Can be nil if card is not directly tied to a post
                    actionType: .linkOpen,
                    accountID: currentUserAccountID,
                    authorAccountID: nil, // Card doesn't directly store post author ID
                    postURL: postID != nil ? card.url : nil, // Log postURL only if postID is present
                    tags: nil, // Tags are not directly available on Card model
                    linkURL: urlToOpen.absoluteString
                )

                #if canImport(UIKit) && !os(watchOS)
                UIApplication.shared.open(urlToOpen)
                #else
                print("UIApplication not available to open URL.")
                #endif
            }
        }
    }
}

// Helper to use SFSafariViewController if available (typically in a UIViewControllerRepresentable)
// This part is more for a full app context and might not be directly usable/testable in the worker
// without additional setup. For now, `UIApplication.shared.open` is a simpler approach.
// The SafariView struct previously here has been removed to consolidate with the one in Utilities/WebView.swift
#if canImport(UIKit) && !os(watchOS)
// struct SafariView has been removed.
#endif
