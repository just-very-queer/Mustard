//
//  PostRow.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct PostRow: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                NavigationLink(destination: ProfileView(user: post.account!.toUser())) {
                    AvatarView(url: post.account?.avatar, size: 40)
                    VStack(alignment: .leading) {
                        Text(post.account?.display_name ?? "")
                            .font(.headline)
                        Text("@\(post.account?.acct ?? "")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                // No date formatting needed here, as Post.createdAt is now a Date
                Text(timeAgoSinceDate(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(parsePostContent(post.content))
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            
            if !post.mediaAttachments.isEmpty {
                // Use MediaAttachmentView from CombinedUtilityViews instead of MediaGridView.
                MediaAttachmentView(post: post, onImageTap: {
                    // Implement any desired tap action here (for example, showing a full-screen image).
                })
            }
            
            PostActionsView(post: post, viewModel: viewModel)
        }
        .padding(.vertical)
    }
    
    private func timeAgoSinceDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func parsePostContent(_ htmlContent: String) -> AttributedString {
        let strippedHTML = HTMLUtils.convertHTMLToPlainText(html: htmlContent)
        var attributedString = AttributedString(strippedHTML)
        
        // Correctly handle optional mentions
        if let mentions = post.mentions {
            for mention in mentions {
                let mentionSearchString = "@\(mention.username)"
                // Use the extension method correctly
                let ranges = attributedString.ranges(of: mentionSearchString)
                for range in ranges {
                    attributedString[range].foregroundColor = .blue
                    attributedString[range].link = URL(string: "mstdn://\(mention.id)")
                }
            }
        }
        return attributedString
    }
}

// MARK: - AttributedString Extension
// Extension must be at file scope, not nested within PostRow
extension AttributedString {
    /// Returns all ranges of occurrences of the given substring.
    func ranges(of substring: String) -> [Range<AttributedString.Index>] {
        var ranges: [Range<AttributedString.Index>] = []
        var start = self.startIndex
        //Specify range and options.
        while start < self.endIndex,
              let range = self.range(of: substring, options: .caseInsensitive) //Added search range
        {
            ranges.append(range)
            start = range.upperBound
        }
        return ranges
    }
}
