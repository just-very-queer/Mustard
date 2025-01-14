//
//  CombinedUtilityViews.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import OSLog
import SafariServices

// MARK: -

struct User: Decodable {
    let id: String
    let username: String
    let displayName: String
    let avatar: URL?
    let instanceURL: URL
}

// MARK: - Avatar View
struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable().scaledToFill().clipShape(Circle())
            case .failure:
                Image(systemName: "person.crop.circle.fill")
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(Color.gray.opacity(0.3)))
    }
}

// MARK: - Action Button View
struct ActionButton: View {
    let image: String
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: image).foregroundColor(color)
                Text(text)
            }
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        Group {
            if isLoading {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                ProgressView(message)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - Link Preview
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

// MARK: - Full-Screen Image View
struct FullScreenImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.edgesIgnoringSafeArea(.all)

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

// MARK: - Safari Web View
struct SafariWebView: View {
    let url: URL

    var body: some View {
        SafariView(url: url).edgesIgnoringSafeArea(.all)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - HTML Utilities
struct HTMLUtils {
    /// Converts an HTML string to plain text
    static func convertHTMLToPlainText(html: String) -> String {
        guard let data = html.data(using: .utf16) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? html
    }

    /// Extracts links from an HTML string
    static func extractLinks(from html: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        return matches.compactMap { $0.url }
    }
}

// MARK: - URL Detection Extension
extension URL {
    /// Detects the first URL in a given content string
    static func detect(from content: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))?.url
    }
}

// MARK: - Previews
struct CombinedUtilityViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AvatarView(url: URL(string: "https://example.com/avatar.png"), size: 50)
            ActionButton(image: "heart.fill", text: "Like", color: .red) { print("Liked!") }
            LoadingOverlay(isLoading: true, message: "Loading...")
            LinkPreview(url: URL(string: "https://example.com")!) { print("Link tapped!") }
        }
        .padding()
    }
}

