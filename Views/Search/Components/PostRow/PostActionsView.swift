//
//  PostActionsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct PostActionsView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isLiked: Bool = false
    @State private var isReposted: Bool = false

    var body: some View {
        HStack {
            Button {
                Task { await toggleLike() }
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .red : .gray)
            }
            
            Spacer()
            
            Button {
                Task { await toggleRepost() }
            } label: {
                Image(systemName: isReposted ? "arrow.uturn.forward.circle.fill" : "arrow.rectanglepath")
                    .foregroundColor(isReposted ? .green : .gray)
            }
            
            Spacer()
            
            NavigationLink {
                // Pass constant bindings since PostActionsView isn’t managing comments.
                ExpandedCommentsSection(
                    post: post,
                    isExpanded: .constant(false),
                    commentText: .constant(""),
                    viewModel: viewModel
                )
            } label: {
                Image(systemName: "bubble.left")
            }
            
            Spacer()
            
            Button {
                // Handle more options
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
    
    private func toggleLike() async {
        do {
            if isLiked {
                try await viewModel.postActionService.toggleLike(postID: post.id)
            } else {
                try await viewModel.postActionService.toggleLike(postID: post.id)
            }
            isLiked.toggle()
        } catch {
            print("Like error: \(error)")
        }
    }
    
    private func toggleRepost() async {
        do {
            if isReposted {
                try await viewModel.postActionService.toggleRepost(postID: post.id)
            } else {
                try await viewModel.postActionService.toggleRepost(postID: post.id)
            }
            isReposted.toggle()
        } catch {
            print("Repost error: \(error)")
        }
    }
}

