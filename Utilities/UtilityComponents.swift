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

import SafariServices // Required for SFSafariViewController

struct LinkPreview: View {
    let card: Card

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
                // In a real app, you'd use SFSafariViewController or similar
                // For worker environment, this action might not be directly testable
                // but the structure is important.
                print("Attempting to open URL: \(urlToOpen)")
                #if canImport(UIKit) && !os(watchOS)
                UIApplication.shared.open(urlToOpen)
                #else
                // Fallback for environments where UIApplication is not available
                // This could involve opening in a default browser if possible
                // For now, just print.
                print("UIApplication not available to open URL.")
                #endif
            }
        }
    }
}

// Helper to use SFSafariViewController if available (typically in a UIViewControllerRepresentable)
// This part is more for a full app context and might not be directly usable/testable in the worker
// without additional setup. For now, `UIApplication.shared.open` is a simpler approach.
#if canImport(UIKit) && !os(watchOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // No update needed
    }
}
#endif
