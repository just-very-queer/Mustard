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


struct BrowserView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    
    var body: some View {
        SafariWebView(post: post)
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

