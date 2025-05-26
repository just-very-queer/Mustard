//  WebView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI
import SafariServices
import SwiftSoup

// MARK: - Web Components

struct WebView: View {
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
