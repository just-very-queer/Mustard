//
//  TimelineContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import SwiftUI

struct TimelineContentView: View {
    let posts: [Post]
    let isLoading: Bool

    /// If you need to pass the ViewModel along (for like/repost/comment actions), inject it:
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(posts) { post in
                    /// Important: pass the *instance* of the viewModel, not the *type* itself.
                    PostView(post: post, viewModel: viewModel)
                        .padding(.vertical, 4)
                    Divider()
                }
                
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
}

