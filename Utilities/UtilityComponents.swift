//
//  UtilityComponents.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI
import SwiftData

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
    let card: Card
    let postID: String?
    let currentUserAccountID: String?

    var body: some View {
        VStack(alignment: .leading) {
            if let imageURLString = card.image, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 150)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo")
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

                // FIX: Use card.summary instead of card.description
                if !card.summary.isEmpty {
                    Text(card.summary)
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
                    Spacer()
                }
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .onTapGesture {
            if let urlToOpen = URL(string: card.embedUrl ?? card.url) {
                print("Attempting to open URL: \(urlToOpen)")

                RecommendationService.shared.logInteraction(
                    statusID: postID,
                    actionType: InteractionType.linkOpen,
                    accountID: currentUserAccountID,
                    authorAccountID: nil,
                    postURL: postID != nil ? card.url : nil,
                    tags: nil,
                    viewDuration: nil,
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
